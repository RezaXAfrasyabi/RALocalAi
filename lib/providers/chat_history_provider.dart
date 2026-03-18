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

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat.dart';
import '../models/chat_message.dart';

const _kChatListKey = 'chat_history_list';
const _kCurrentChatIdKey = 'current_chat_id';

/// Persistent chat history state.
///
/// This represents:
/// - The list of saved chats
/// - The currently selected chat id
class ChatHistoryState {
  final List<Chat> chats;
  final String? currentChatId;

  /// Creates a new state instance.
  ChatHistoryState({
    List<Chat>? chats,
    this.currentChatId,
  }) : chats = chats ?? [];

  /// Returns the currently selected chat, if any.
  Chat? get currentChat {
    if (currentChatId == null) return null;
    try {
      return chats.firstWhere((c) => c.id == currentChatId);
    } catch (_) {
      return null;
    }
  }
}

/// Manages chat history persistence to local storage.
///
/// Implementation notes:
/// - Stores chats as JSON in `SharedPreferences`
/// - Always keeps at least one chat present (similar to ChatGPT)
class ChatHistoryNotifier extends StateNotifier<ChatHistoryState> {
  ChatHistoryNotifier() : super(ChatHistoryState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final listJson = prefs.getString(_kChatListKey);
    final currentId = prefs.getString(_kCurrentChatIdKey);
    List<Chat> list = [];
    if (listJson != null && listJson.isNotEmpty) {
      try {
        final listDynamic = jsonDecode(listJson) as List<dynamic>;
        list = listDynamic
            .map((e) => Chat.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    // Sort by createdAt desc (newest first) — list must be mutable
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    var effectiveCurrentId = currentId;
    if (list.isEmpty) {
      // Ensure there is always at least one chat (like ChatGPT).
      final newChat = Chat(id: DateTime.now().millisecondsSinceEpoch.toString(), title: 'New chat');
      list = [newChat];
      effectiveCurrentId = newChat.id;
      state = ChatHistoryState(chats: list, currentChatId: effectiveCurrentId);
      _save();
      return;
    }
    if (effectiveCurrentId == null || !list.any((c) => c.id == effectiveCurrentId)) {
      effectiveCurrentId = list.first.id;
    }
    state = ChatHistoryState(chats: list, currentChatId: effectiveCurrentId);
    _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final listJson = jsonEncode(state.chats.map((c) => c.toJson()).toList());
    await prefs.setString(_kChatListKey, listJson);
    if (state.currentChatId != null) {
      await prefs.setString(_kCurrentChatIdKey, state.currentChatId!);
    } else {
      await prefs.remove(_kCurrentChatIdKey);
    }
  }

  /// Create a new chat and set it as current. Returns the new chat id.
  String createNewChat() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final chat = Chat(id: id, title: 'New chat');
    final list = [chat, ...state.chats];
    state = ChatHistoryState(chats: list, currentChatId: id);
    _save();
    return id;
  }

  void setCurrentChatId(String? id) {
    state = ChatHistoryState(chats: state.chats, currentChatId: id);
    _save();
  }

  /// Replaces the message list for [chatId].
  void updateChatMessages(String chatId, List<ChatMessage> messages) {
    final index = state.chats.indexWhere((c) => c.id == chatId);
    if (index < 0) return;
    final chat = state.chats[index];
    final updated = chat.copyWith(
      messages: List<ChatMessage>.from(messages),
    );
    final list = List<Chat>.from(state.chats)..[index] = updated;
    state = ChatHistoryState(chats: list, currentChatId: state.currentChatId);
    _save();
  }

  /// Updates the human-readable title for [chatId].
  void updateChatTitle(String chatId, String title) {
    final index = state.chats.indexWhere((c) => c.id == chatId);
    if (index < 0) return;
    final chat = state.chats[index];
    final updated = chat.copyWith(title: title);
    final list = List<Chat>.from(state.chats)..[index] = updated;
    state = ChatHistoryState(chats: list, currentChatId: state.currentChatId);
    _save();
  }

  /// Deletes a chat and ensures a valid current chat remains selected.
  void deleteChat(String chatId) {
    var list = state.chats.where((c) => c.id != chatId).toList();
    var newCurrent = state.currentChatId;
    if (newCurrent == chatId) {
      newCurrent = list.isNotEmpty ? list.first.id : null;
    }
    // If no chats left, create one (like ChatGPT).
    if (list.isEmpty) {
      final newChat = Chat(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'New chat',
      );
      list = [newChat];
      newCurrent = newChat.id;
    }
    state = ChatHistoryState(chats: list, currentChatId: newCurrent);
    _save();
  }

  /// Returns the chat with [id], or `null` if not found.
  Chat? getChat(String id) {
    try {
      return state.chats.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Riverpod provider exposing chat history state.
final chatHistoryProvider =
    StateNotifierProvider<ChatHistoryNotifier, ChatHistoryState>(
        (ref) => ChatHistoryNotifier());

/// Current chat id for convenience.
final currentChatIdProvider = Provider<String?>((ref) {
  return ref.watch(chatHistoryProvider).currentChatId;
});
