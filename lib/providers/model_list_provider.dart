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
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kModelListKey = 'model_list';
const _kCurrentModelPathKey = 'current_model_path';

/// Metadata for a model file the user has loaded at least once.
class SavedModel {
  /// Absolute path to the GGUF file.
  final String path;

  /// Display name derived from [path] (file name).
  final String name;

  /// Size of the file in bytes, if known.
  final int? sizeBytes;

  /// Creates a saved model record.
  const SavedModel({
    required this.path,
    required this.name,
    this.sizeBytes,
  });

  /// Human-readable representation of [sizeBytes].
  String get sizeDisplay {
    if (sizeBytes == null) return '—';
    if (sizeBytes! < 1024) return '$sizeBytes B';
    if (sizeBytes! < 1024 * 1024) return '${(sizeBytes! / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes! < 1024 * 1024 * 1024) {
      return '${(sizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes! / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'sizeBytes': sizeBytes,
      };

  factory SavedModel.fromJson(Map<String, dynamic> json) {
    return SavedModel(
      path: json['path'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sizeBytes: json['sizeBytes'] as int?,
    );
  }
}

/// State for the saved model list and currently selected model.
class ModelListState {
  final List<SavedModel> models;
  final String? currentPath;

  const ModelListState({
    this.models = const [],
    this.currentPath,
  });

  /// Returns the model corresponding to [currentPath], if any.
  SavedModel? get currentModel {
    if (currentPath == null) return null;
    try {
      return models.firstWhere((m) => m.path == currentPath);
    } catch (_) {
      return null;
    }
  }
}

/// Persists and manages the list of models shown in the drawer.
class ModelListNotifier extends StateNotifier<ModelListState> {
  ModelListNotifier() : super(const ModelListState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getString(_kModelListKey);
      final currentPath = prefs.getString(_kCurrentModelPathKey);
      List<SavedModel> list = [];
      if (listJson != null && listJson.isNotEmpty) {
        final listDynamic = jsonDecode(listJson) as List<dynamic>;
        list = listDynamic
            .map((e) => SavedModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      state = ModelListState(models: list, currentPath: currentPath);
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kModelListKey,
      jsonEncode(state.models.map((m) => m.toJson()).toList()),
    );
    if (state.currentPath != null) {
      await prefs.setString(_kCurrentModelPathKey, state.currentPath!);
    } else {
      await prefs.remove(_kCurrentModelPathKey);
    }
  }

  /// Add or update a model in the list. Call when user loads a model.
  void addModel(String path, {int? sizeBytes}) {
    final file = File(path);
    final name = path.split(RegExp(r'[/\\]')).last;
    final size = sizeBytes ?? (file.existsSync() ? file.lengthSync() : null);
    final existing = state.models.indexWhere((m) => m.path == path);
    List<SavedModel> list;
    if (existing >= 0) {
      list = List<SavedModel>.from(state.models);
      list[existing] = SavedModel(path: path, name: name, sizeBytes: size);
    } else {
      list = [SavedModel(path: path, name: name, sizeBytes: size), ...state.models];
    }
    state = ModelListState(models: list, currentPath: path);
    _save();
  }

  void setCurrentPath(String? path) {
    state = ModelListState(models: state.models, currentPath: path);
    _save();
  }

  /// Removes a model entry from the list (does not delete the file).
  void removeModel(String path) {
    final list = state.models.where((m) => m.path != path).toList();
    final newCurrent = state.currentPath == path
        ? (list.isNotEmpty ? list.first.path : null)
        : state.currentPath;
    state = ModelListState(models: list, currentPath: newCurrent);
    _save();
  }

  /// Refresh file size for a path (e.g. after download).
  void refreshSize(String path) {
    final file = File(path);
    if (!file.existsSync()) return;
    final size = file.lengthSync();
    final idx = state.models.indexWhere((m) => m.path == path);
    if (idx < 0) return;
    final m = state.models[idx];
    final list = List<SavedModel>.from(state.models);
    list[idx] = SavedModel(path: m.path, name: m.name, sizeBytes: size);
    state = ModelListState(models: list, currentPath: state.currentPath);
    _save();
  }
}

/// Riverpod provider exposing the saved-model list.
final modelListProvider =
    StateNotifierProvider<ModelListNotifier, ModelListState>(
        (ref) => ModelListNotifier());
