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
import 'dart:io';

import 'package:flutter_llama/flutter_llama.dart';

import 'app_log_service.dart';
import '../utils/ai_formatter.dart';

/// Generation parameters that can be passed from UI settings.
///
/// This type is intentionally UI-friendly (immutable, `const`-constructible)
/// and maps 1:1 to `flutter_llama` generation parameters.
class GenerationOptions {
  /// Sampling temperature.
  final double temperature;

  /// Nucleus sampling probability.
  final double topP;

  /// Top-k sampling cutoff.
  final int topK;

  /// Maximum number of tokens to generate for a single response.
  final int maxTokens;

  /// Penalty applied to repeated tokens (values > 1.0 reduce repetition).
  final double repeatPenalty;

  /// Creates generation options with sensible defaults for chat.
  const GenerationOptions({
    this.temperature = 0.7,
    this.topP = 0.9,
    this.topK = 40,
    this.maxTokens = 512,
    this.repeatPenalty = 1.1,
  });
}

/// High-level inference service for running GGUF models locally.
///
/// This class intentionally hides `flutter_llama` behind a small, testable API:
/// - **App layer** talks to `LocalAiService`
/// - **Implementation** delegates to a `FlutterLlama` instance
///
/// Design goals:
/// - **Dependency-injectable** (no hard singleton requirement)
/// - **Deterministic lifecycle** (`dispose()` always releases native resources)
/// - **Streaming-first** UX (`stream` emits partial text)
class LocalAiService {
  /// Creates a new instance.
  ///
  /// If [llama] is omitted, uses `FlutterLlama.instance`.
  LocalAiService({FlutterLlama? llama}) : _llama = llama ?? FlutterLlama.instance;

  final FlutterLlama _llama;

  StreamController<String> _streamController = StreamController<String>.broadcast();

  bool _isModelLoaded = false;
  bool _isGenerating = false;
  String _currentModelName = '';
  StreamSubscription<String>? _streamSubscription;
  Completer<String>? _streamCompleter;
  final StringBuffer _streamBuffer = StringBuffer();

  /// Whether a model is loaded and ready for inference.
  bool get isReady => _isModelLoaded;

  /// Whether a generation call is currently in progress.
  bool get isGenerating => _isGenerating;

  /// Stream of generated output for real-time UI updates.
  ///
  /// The service emits the **accumulated** text (not individual tokens) so UI
  /// can render a single “assistant bubble” without manual concatenation.
  Stream<String> get stream => _streamController.stream;

  /// Load a GGUF model from [modelPath].
  ///
  /// [contextSize] controls how many tokens of chat history + current message the
  /// model can attend to. This only takes effect at load time.
  Future<void> loadModel(String modelPath, {int? contextSize}) async {
    appLogService.log('Unloading previous model (if any)…');
    await dispose();
    _streamController = StreamController<String>.broadcast();

    final path = modelPath.trim();
    final file = File(path);
    if (!file.existsSync()) {
      appLogService.logError('Model file not found: $path');
      throw Exception('Model file not found: $path');
    }

    appLogService.log('Initializing GGUF model (context: ${contextSize ?? 2048})…');
    final nCtx = contextSize ?? 2048;
    final config = LlamaConfig(
      modelPath: file.absolute.path,
      contextSize: nCtx,
      // Conservative defaults; prefer stability over saturating small devices.
      nThreads: Platform.isAndroid ? 4 : 8,
      nGpuLayers: -1,
      batchSize: 256,
      useGpu: true,
      verbose: false,
    );

    final ok = await _llama.loadModel(config);
    if (!ok) {
      appLogService.logError('Native loadModel returned false: ${file.absolute.path}');
      throw Exception('Failed to load model at ${file.absolute.path}');
    }

    _isModelLoaded = true;
    _currentModelName = path.split(RegExp(r'[/\\]')).last;
    appLogService.log('Model ready for inference (prompt format from: $_currentModelName).');
  }

  static const _stopSequences = [
    '\nUser message:',
    '\nUser:',
    '\nAssistant message:',
    '\nAssistant:',
    '<|eot_id|>',
    '<|im_end|>',
    '<end_of_turn>',
  ];

  /// Builds prompt using the format for the current (or overridden) model type.
  String _buildPrompt(String userMessage, [ModelType? typeOverride]) {
    const system = r'''You are a helpful, concise AI assistant in a chat app on a phone.
Reply with ONE short, direct answer in plain language.
Do NOT prefix lines with "User", "Assistant", or anything similar.
Do NOT show example conversations.
Do NOT repeat earlier messages.
Only output the final answer sentence(s).''';
    final type = typeOverride ?? AIFormatter.inferFromModelName(_currentModelName);
    return AIFormatter.buildPrompt(system: system, user: userMessage, type: type);
  }

  GenerationParams _buildParams(String composedPrompt, GenerationOptions options) {
    return GenerationParams(
      prompt: composedPrompt,
      temperature: options.temperature,
      topP: options.topP,
      topK: options.topK,
      maxTokens: options.maxTokens,
      repeatPenalty: options.repeatPenalty,
      stopSequences: _stopSequences,
    );
  }

  /// Generate a response with streaming output.
  ///
  /// Emits accumulated text to [stream] and returns the full text when done
  /// (or partial text if [stop] was called).
  /// [promptFormat] overrides auto-detection from model name when non-null.
  Future<String> sendPromptStream(
    String prompt, {
    required GenerationOptions options,
    ModelType? promptFormat,
  }) async {
    if (!_isModelLoaded) {
      throw StateError('Model not loaded. Call loadModel first.');
    }
    _isGenerating = true;
    _streamBuffer.clear();
    _streamCompleter = Completer<String>();
    appLogService.log('Starting stream generation (maxTokens: ${options.maxTokens})…');

    final composedPrompt = _buildPrompt(prompt, promptFormat);
    final params = _buildParams(composedPrompt, options);

    try {
      await _streamSubscription?.cancel();
      _streamSubscription = _llama.generateStream(params).listen(
        (token) {
          _streamBuffer.write(token);
          _streamController.add(_streamBuffer.toString());
        },
        onError: (e) {
          appLogService.logError('Stream error: $e');
          if (!(_streamCompleter?.isCompleted ?? true)) {
            _streamCompleter?.completeError(e);
          }
        },
        onDone: () {
          if (!(_streamCompleter?.isCompleted ?? true)) {
            _streamCompleter?.complete(_streamBuffer.toString());
          }
        },
        cancelOnError: true,
      );
      final result = await _streamCompleter!.future;
      appLogService.log('Stream generation done (${result.length} chars).');
      return result;
    } finally {
      _isGenerating = false;
      _streamSubscription = null;
    }
  }

  /// Stop ongoing generation. The current [sendPromptStream] future will
  /// complete with the text generated so far.
  Future<void> stop() async {
    appLogService.logWarn('Stopping generation…');
    _isGenerating = false;
    await _streamSubscription?.cancel();
    if (_streamCompleter != null && !_streamCompleter!.isCompleted) {
      _streamCompleter!.complete(_streamBuffer.toString());
    }
    await _llama.stopGeneration();
  }

  /// Non-streaming fallback (e.g. if streaming fails on platform).
  Future<String> sendPrompt(
    String prompt, {
    GenerationOptions options = const GenerationOptions(),
    ModelType? promptFormat,
  }) async {
    if (!_isModelLoaded) {
      throw StateError('Model not loaded. Call loadModel first.');
    }
    _isGenerating = true;
    appLogService.log('Starting blocking generation…');
    try {
      final composedPrompt = _buildPrompt(prompt, promptFormat);
      final params = _buildParams(composedPrompt, options);
      final response = await _llama.generate(params);
      final text = response.text;
      if (text.isNotEmpty) {
        _streamController.add(text);
      }
      appLogService.log('Blocking generation done (${text.length} chars).');
      return text;
    } finally {
      _isGenerating = false;
    }
  }

  /// Compatibility shim for older call sites; this app stores chat history in Dart.
  void addMessage(String role, String content) {
    // flutter_llama does not keep a built-in message history; the UI does.
  }

  /// Releases native model resources and closes any active streams.
  Future<void> dispose() async {
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _streamCompleter = null;
    if (_isModelLoaded) {
      await _llama.unloadModel();
      _isModelLoaded = false;
    }
    if (!_streamController.isClosed) {
      await _streamController.close();
    }
  }
}

