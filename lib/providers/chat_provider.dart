/*
 * Copyright (C) 2026 Reza Afrasyabi afrasyabireza50@gmail.com
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../services/app_log_service.dart';
import '../services/local_ai_service.dart';
import 'app_providers.dart';
import 'chat_history_provider.dart';
import 'generation_settings_provider.dart';
import 'model_list_provider.dart';

/// Immutable UI state for the chat experience.
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoadingModel;
  final bool isGenerating;
  final String streamingContent;
  final String? error;

  /// Creates a new [ChatState].
  const ChatState({
    this.messages = const [],
    this.isLoadingModel = false,
    this.isGenerating = false,
    this.streamingContent = '',
    this.error,
  });

  /// Creates a modified copy of this state.
  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoadingModel,
    bool? isGenerating,
    String? streamingContent,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoadingModel: isLoadingModel ?? this.isLoadingModel,
      isGenerating: isGenerating ?? this.isGenerating,
      streamingContent: streamingContent ?? this.streamingContent,
      error: error,
    );
  }
}

/// Coordinates chat UI actions with the local inference runtime.
///
/// Responsibilities:
/// - Load models and persist “last used” model
/// - Append user/assistant messages
/// - Drive streaming UI updates while a response is generating
/// - Persist chat history to local storage
class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._ref) : super(const ChatState());

  final Ref _ref;
  bool _stoppedByUser = false;

  /// Loads a GGUF model and updates providers used by the UI.
  Future<void> loadModel(String path) async {
    state = state.copyWith(isLoadingModel: true, error: null);
    appLogService.log('Loading model: $path');
    try {
      final service = _ref.read(localAiServiceProvider);
      final contextSize = _ref.read(generationSettingsProvider).contextSize;
      await service.loadModel(path, contextSize: contextSize);

      await saveLastModelPath(path);
      _ref.read(modelListProvider.notifier).addModel(path);
      _ref.read(modelListProvider.notifier).setCurrentPath(path);
      state = state.copyWith(isLoadingModel: false, error: null);
      appLogService.log('Model loaded successfully.');
    } catch (e) {
      appLogService.logError('Model load failed: $e');
      state = state.copyWith(
        isLoadingModel: false,
        error: e.toString(),
      );
    }
  }

  /// Stop the current AI generation. Partial response is kept as the assistant message.
  Future<void> stopGeneration() async {
    final service = _ref.read(localAiServiceProvider);
    if (!service.isGenerating) return;
    _stoppedByUser = true;
    // Fire-and-forget to avoid blocking UI if the native side is slow.
    unawaited(service.stop());
  }

  StreamSubscription<String>? _streamSub;

  /// Sends a user message and generates the assistant response.
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _stoppedByUser = false;
    final service = _ref.read(localAiServiceProvider);
    if (!service.isReady) {
      state = state.copyWith(
        error: 'Load a model first. Tap the menu and select a .gguf file.',
      );
      return;
    }

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isUser: true,
      content: text.trim(),
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      error: null,
      isGenerating: true,
      streamingContent: '',
    );
    _persistMessages();
    _maybeUpdateTitle(userMsg.content);

    service.addMessage('user', userMsg.content);
    appLogService.log('Generating response…');
    final options = _ref.read(generationSettingsProvider);
    final genOptions = GenerationOptions(
      temperature: options.temperature,
      topP: options.topP,
      topK: options.topK,
      maxTokens: options.maxTokens,
      repeatPenalty: options.repeatPenalty,
    );

    String assistantText;
    try {
      // Subscribe to stream for real-time UI updates
      unawaited(_streamSub?.cancel());
      _streamSub = service.stream.listen((content) {
        state = state.copyWith(streamingContent: content);
      });

      final promptFormat = _ref.read(generationSettingsProvider).promptFormat;
      try {
        assistantText = await service.sendPromptStream(
          text.trim(),
          options: genOptions,
          promptFormat: promptFormat,
        );
      } catch (streamError) {
        // Fallback to non-streaming if platform doesn't support EventChannel (e.g. some Android)
        await _streamSub?.cancel();
        _streamSub = null;
        assistantText = await service.sendPrompt(
          text.trim(),
          options: genOptions,
          promptFormat: promptFormat,
        );
      }
    } catch (e) {
      appLogService.logError('Generation failed: $e');
      state = state.copyWith(
        isGenerating: false,
        streamingContent: '',
        error: 'Failed to send: $e',
      );
      await _streamSub?.cancel();
      _streamSub = null;
      return;
    } finally {
      await _streamSub?.cancel();
      _streamSub = null;
    }

    final stopped = _stoppedByUser;
    _stoppedByUser = false;

    state = state.copyWith(streamingContent: '', isGenerating: false);
    final fullContent = assistantText.trim();

    final updated = List<ChatMessage>.from(state.messages);
    if (fullContent.isNotEmpty) {
      final assistantMsg = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        isUser: false,
        content: fullContent,
      );
      service.addMessage('assistant', fullContent);
      updated.add(assistantMsg);
    }

    if (stopped) {
      appLogService.logWarn('Generation stopped by user.');
      updated.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          isUser: false,
          content: 'Generation stopped by user.',
        ),
      );
    } else {
      appLogService.log('Generation complete.');
    }

    if (updated.isEmpty) return;
    state = state.copyWith(messages: updated);
    _persistMessages();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Load messages for the current chat from history. Call on startup and when switching chats.
  void loadCurrentChat() {
    final history = _ref.read(chatHistoryProvider);
    final id = history.currentChatId;
    loadChat(id);
  }

  /// Load a specific chat by id. Pass null to clear messages.
  void loadChat(String? chatId) {
    if (chatId == null) {
      state = state.copyWith(messages: [], streamingContent: '', error: null);
      return;
    }
    final chat = _ref.read(chatHistoryProvider.notifier).getChat(chatId);
    state = state.copyWith(
      messages: chat != null ? List<ChatMessage>.from(chat.messages) : [],
      streamingContent: '',
      error: null,
    );
  }

  void _persistMessages() {
    final id = _ref.read(chatHistoryProvider).currentChatId;
    if (id == null) return;
    _ref.read(chatHistoryProvider.notifier).updateChatMessages(id, state.messages);
  }

  void _maybeUpdateTitle(String firstUserMessage) {
    final history = _ref.read(chatHistoryProvider);
    final chat = history.currentChat;
    if (chat == null || chat.title != 'New chat') return;
    final title = firstUserMessage.length > 40
        ? '${firstUserMessage.substring(0, 40)}…'
        : firstUserMessage;
    _ref.read(chatHistoryProvider.notifier).updateChatTitle(chat.id, title);
  }
}

/// Riverpod provider that exposes the current [ChatState] and controller.
final chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) => ChatNotifier(ref));
