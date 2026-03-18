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

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/ai_model_list_item.dart';
import '../services/app_log_service.dart';
import 'chat_provider.dart';

/// Download lifecycle state for a single GGUF model file.
enum ModelDownloadStatus {
  idle,
  inProgress,
  completed,
  error,
}

/// Immutable UI state describing the current (or most recent) download.
class ModelDownloadState {
  /// User-facing model name.
  final String? modelName;

  /// Destination file path, if known.
  final String? filePath;

  /// Progress value in the range 0..1.
  final double progress; // 0..1

  /// Current throughput estimate for display, in bytes per second.
  final int bytesPerSecond;

  /// Current state of the download.
  final ModelDownloadStatus status;

  /// Error message when [status] is [ModelDownloadStatus.error].
  final String? errorMessage;

  /// Creates a new state instance.
  const ModelDownloadState({
    this.modelName,
    this.filePath,
    this.progress = 0,
    this.bytesPerSecond = 0,
    this.status = ModelDownloadStatus.idle,
    this.errorMessage,
  });

  /// Creates a modified copy of this state.
  ModelDownloadState copyWith({
    String? modelName,
    String? filePath,
    double? progress,
    int? bytesPerSecond,
    ModelDownloadStatus? status,
    String? errorMessage,
  }) {
    return ModelDownloadState(
      modelName: modelName ?? this.modelName,
      filePath: filePath ?? this.filePath,
      progress: progress ?? this.progress,
      bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

/// Downloads a selected model to shared storage and triggers loading.
///
/// Design constraints:
/// - One active download at a time
/// - Best-effort resume using HTTP Range when supported
class ModelDownloadNotifier extends StateNotifier<ModelDownloadState> {
  ModelDownloadNotifier(this._ref) : super(const ModelDownloadState());

  final Ref _ref;
  http.Client? _client;

  static const String _androidDownloadRoot = '/storage/emulated/0/RA_LocalAiChat';

  /// Resolves (and creates if needed) the storage directory for downloads.
  Future<Directory?> _resolveStorageDir() async {
    if (Platform.isAndroid) {
      // Shared storage root (internal memory), same folder name as before.
      final target = Directory(_androidDownloadRoot);
      if (!await target.exists()) {
        await target.create(recursive: true);
      }
      return target;
    } else {
      final dir = await getDownloadsDirectory();
      final base = dir?.path ?? '';
      if (base.isEmpty) return null;
      final target = Directory('$base/RA_LocalAiChat');
      if (!await target.exists()) {
        await target.create(recursive: true);
      }
      return target;
    }
  }

  /// Starts downloading [model] to shared storage and loads it on completion.
  Future<void> startDownload(AiModelListItem model) async {
    // Only one download at a time for now.
    if (state.status == ModelDownloadStatus.inProgress) return;
    if (model.downloadUrl.isEmpty) return;

    final dir = await _resolveStorageDir();
    if (dir == null) {
      state = state.copyWith(
        status: ModelDownloadStatus.error,
        errorMessage: 'Could not access storage folder RA_LocalAiChat.',
      );
      return;
    }

    final uri = Uri.tryParse(model.downloadUrl);
    if (uri == null) {
      state = state.copyWith(
        status: ModelDownloadStatus.error,
        errorMessage: 'Invalid download URL for this model.',
      );
      return;
    }

    final fileName =
        model.ggufFile.isNotEmpty ? model.ggufFile : '${model.name}.gguf';
    final filePath = '${dir.path}/$fileName';
    final file = File(filePath);

    // Check for existing partial download to support resume.
    int existingBytes = 0;
    if (await file.exists()) {
      existingBytes = await file.length();
    }

    final client = http.Client();
    _client = client;

    final startTime = DateTime.now();
    int received = existingBytes;

    state = ModelDownloadState(
      modelName: model.name,
      filePath: filePath,
      progress: 0,
      bytesPerSecond: 0,
      status: ModelDownloadStatus.inProgress,
    );
    appLogService.log('Download started: ${model.name} → $filePath');

    try {
      final request = http.Request('GET', uri);
      if (existingBytes > 0) {
        request.headers['Range'] = 'bytes=$existingBytes-';
      }

      final response = await client.send(request);

      // If server ignores Range and returns full file, start from scratch.
      if (response.statusCode == 200 && existingBytes > 0) {
        existingBytes = 0;
        received = 0;
        await file.writeAsBytes(const []);
      } else if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      final streamedLength = response.contentLength ?? 0;
      final totalLength =
          streamedLength > 0 ? existingBytes + streamedLength : 0;

      final sink = file.openWrite(
        mode: existingBytes > 0 ? FileMode.append : FileMode.write,
      );

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;

        if (totalLength > 0) {
          final elapsedMs =
              DateTime.now().difference(startTime).inMilliseconds;
          final bps =
              elapsedMs > 0 ? (received * 1000 ~/ elapsedMs) : 0;

          // Throttle UI updates a bit to avoid excessive rebuilds.
          state = state.copyWith(
            progress: received / totalLength,
            bytesPerSecond: bps,
          );
        }
      }

      await sink.close();

      // Load the model exactly like "Use external model": same path format and same load flow.
      appLogService.log('Download complete. Loading model…');
      final absolutePath = File(filePath).absolute.path;
      await _ref.read(chatProvider.notifier).loadModel(absolutePath);

      state = state.copyWith(
        status: ModelDownloadStatus.completed,
        progress: 1,
        bytesPerSecond: 0,
        errorMessage: null,
      );
      appLogService.log('Model download and load finished.');
    } catch (e, stack) {
      appLogService.logError('Model download error: $e');
      debugPrint('Model download error: $e\n$stack');
      state = state.copyWith(
        status: ModelDownloadStatus.error,
        errorMessage: e.toString(),
      );
    } finally {
      _client?.close();
      _client = null;
    }
  }

  /// Cancels any active download and resets the state to idle.
  Future<void> cancel() async {
    _client?.close();
    _client = null;
    state = const ModelDownloadState(status: ModelDownloadStatus.idle);
  }
}

/// Riverpod provider exposing the current download state.
final modelDownloadProvider =
    StateNotifierProvider<ModelDownloadNotifier, ModelDownloadState>(
  (ref) => ModelDownloadNotifier(ref),
);

