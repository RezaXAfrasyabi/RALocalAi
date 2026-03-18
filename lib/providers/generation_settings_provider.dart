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

import '../utils/ai_formatter.dart';

const _kGenerationSettingsKey = 'generation_settings';

/// Supported context sizes (tokens). Takes effect after next model load.
const List<int> kContextSizeOptions = [512, 1024, 2048, 4096, 8192];

/// Persisted generation settings used for local inference.
///
/// This is the single source of truth for parameters edited in
/// `GenerationSettingsScreen`.
class GenerationSettings {
  final double temperature;
  final double topP;
  final int topK;
  final int maxTokens;
  final double repeatPenalty;
  final int contextSize;

  /// null = auto-detect from model name; otherwise use this prompt format.
  final ModelType? promptFormat;

  /// Creates generation settings with chat-friendly defaults.
  const GenerationSettings({
    this.temperature = 0.7,
    this.topP = 0.9,
    this.topK = 40,
    this.maxTokens = 512,
    this.repeatPenalty = 1.1,
    this.contextSize = 2048,
    this.promptFormat,
  });

  /// Creates a modified copy of these settings.
  GenerationSettings copyWith({
    double? temperature,
    double? topP,
    int? topK,
    int? maxTokens,
    double? repeatPenalty,
    int? contextSize,
    ModelType? promptFormat,
  }) {
    return GenerationSettings(
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      topK: topK ?? this.topK,
      maxTokens: maxTokens ?? this.maxTokens,
      repeatPenalty: repeatPenalty ?? this.repeatPenalty,
      contextSize: contextSize ?? this.contextSize,
      promptFormat: promptFormat ?? this.promptFormat,
    );
  }

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'topP': topP,
        'topK': topK,
        'maxTokens': maxTokens,
        'repeatPenalty': repeatPenalty,
        'contextSize': contextSize,
        'promptFormat': promptFormat?.name,
      };

  /// Parses settings from JSON previously produced by [toJson].
  factory GenerationSettings.fromJson(Map<String, dynamic> json) {
    final pf = json['promptFormat'] as String?;
    ModelType? promptFormat;
    if (pf != null && pf.isNotEmpty) {
      try {
        promptFormat = ModelType.values.firstWhere((e) => e.name == pf);
      } catch (_) {}
    }
    return GenerationSettings(
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      topP: (json['topP'] as num?)?.toDouble() ?? 0.9,
      topK: (json['topK'] as int?) ?? 40,
      maxTokens: (json['maxTokens'] as int?) ?? 512,
      repeatPenalty: (json['repeatPenalty'] as num?)?.toDouble() ?? 1.1,
      contextSize: (json['contextSize'] as int?) ?? 2048,
      promptFormat: promptFormat,
    );
  }
}

/// Loads/saves [GenerationSettings] from local storage.
class GenerationSettingsNotifier extends StateNotifier<GenerationSettings> {
  GenerationSettingsNotifier() : super(const GenerationSettings()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kGenerationSettingsKey);
      if (json != null && json.isNotEmpty) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        state = GenerationSettings.fromJson(map);
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kGenerationSettingsKey,
      jsonEncode(state.toJson()),
    );
  }

  void update(GenerationSettings settings) {
    state = settings;
    _save();
  }
}

/// Riverpod provider exposing persisted generation settings.
final generationSettingsProvider =
    StateNotifierProvider<GenerationSettingsNotifier, GenerationSettings>(
        (ref) => GenerationSettingsNotifier());
