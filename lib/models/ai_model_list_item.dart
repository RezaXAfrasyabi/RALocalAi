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

/// One entry from assets/ai_list.json (new schema from Hugging Face export).
class AiModelListItem {
  /// Short model name.
  final String name;

  /// Hugging Face repository identifier.
  final String repoId;

  /// Human-readable description shown in the UI.
  final String description;

  /// Parameter count string (e.g., "3B", "7B").
  final String parametersText;

  /// Tags describing model capabilities (free-form).
  final List<String> abilities;

  /// GGUF file name expected when downloaded.
  final String ggufFile;

  /// GGUF file size in bytes, when provided by the catalog.
  final int? ggufSizeBytes;

  /// Direct download URL for the GGUF artifact.
  final String downloadUrl;

  /// Creates a catalog item.
  const AiModelListItem({
    required this.name,
    required this.repoId,
    required this.description,
    required this.parametersText,
    required this.abilities,
    required this.ggufFile,
    required this.ggufSizeBytes,
    required this.downloadUrl,
  });

  /// Parameters in billions parsed from [parametersText] like "3B", "4B", "15B".
  double get parametersB {
    final raw = parametersText.trim().toUpperCase();
    if (raw.isEmpty) return 0;
    final numeric = raw.replaceAll(RegExp('[^0-9\\.]'), '');
    return double.tryParse(numeric) ?? 0;
  }

  /// RAM needed (GB) ≈ (Parameters in Billions × 0.6) + 1.5
  double get ramNeededGb => (parametersB * 0.6) + 1.5;

  /// User-facing title combining [name] with parameter scale.
  String get displayName => parametersB >= 1
      ? '$name · ${parametersB.toStringAsFixed(parametersB == parametersB.roundToDouble() ? 0 : 1)}B'
      : '$name · ${(parametersB * 1000).round()}M';

  /// Human-readable size string derived from [ggufSizeBytes].
  String get sizeDisplay {
    final bytes = ggufSizeBytes;
    if (bytes == null || bytes <= 0) return 'Size: unknown';
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

  /// Parses a catalog item from JSON.
  factory AiModelListItem.fromJson(Map<String, dynamic> json) {
    return AiModelListItem(
      name: json['name'] as String? ?? '',
      repoId: json['repo_id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      parametersText: json['parameters'] as String? ?? '',
      abilities: (json['abilities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      ggufFile: json['gguf_file'] as String? ?? '',
      ggufSizeBytes: (json['gguf_size_bytes'] is num)
          ? (json['gguf_size_bytes'] as num).toInt()
          : int.tryParse(json['gguf_size_bytes']?.toString() ?? ''),
      downloadUrl: json['download_url'] as String? ?? '',
    );
  }
}
