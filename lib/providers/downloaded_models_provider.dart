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

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// File metadata for a GGUF model present in the downloads folder.
class DownloadedModelInfo {
  final String name;
  final String path;
  final int sizeBytes;

  /// Creates a new model info record.
  const DownloadedModelInfo({
    required this.name,
    required this.path,
    required this.sizeBytes,
  });

  /// Human-readable representation of [sizeBytes].
  String get sizeDisplay {
    final bytes = sizeBytes;
    if (bytes <= 0) return 'Unknown size';
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (bytes >= gb) {
      final v = bytes / gb;
      return '${v.toStringAsFixed(v >= 10 ? 1 : 2)} GB';
    } else if (bytes >= mb) {
      final v = bytes / mb;
      return '${v.toStringAsFixed(v >= 10 ? 1 : 2)} MB';
    } else {
      final v = bytes / kb;
      return '${v.toStringAsFixed(0)} KB';
    }
  }
}

const String _androidDownloadRoot = '/storage/emulated/0/RA_LocalAiChat';

/// Resolves the downloads directory where models are stored.
///
/// Returns `null` if the directory cannot be found (or does not exist).
Future<Directory?> _resolveDownloadsDir() async {
  if (Platform.isAndroid) {
    // Shared storage root (internal memory), same folder name as before.
    final target = Directory(_androidDownloadRoot);
    if (!await target.exists()) return null;
    return target;
  } else {
    final dir = await getDownloadsDirectory();
    final base = dir?.path ?? '';
    if (base.isEmpty) return null;
    final target = Directory('$base/RA_LocalAiChat');
    if (!await target.exists()) return null;
    return target;
  }
}

/// Lists all downloaded GGUF models in the shared storage folder.
final downloadedModelsProvider =
    FutureProvider<List<DownloadedModelInfo>>((ref) async {
  final dir = await _resolveDownloadsDir();
  if (dir == null) return const [];
  final entries = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.gguf'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final models = <DownloadedModelInfo>[];
  for (final f in entries) {
    final name = f.uri.pathSegments.isNotEmpty
        ? f.uri.pathSegments.last
        : f.path.split(Platform.pathSeparator).last;
    final size = await f.length();
    models.add(
      DownloadedModelInfo(
        name: name,
        path: f.path,
        sizeBytes: size,
      ),
    );
  }
  return models;
});

