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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/local_ai_service.dart';

const _kLastModelPathKey = 'last_model_path';

/// Provides a single [LocalAiService] instance for the app lifetime.
///
/// The service is disposed automatically when the provider is torn down.
final localAiServiceProvider = Provider<LocalAiService>((ref) {
  final service = LocalAiService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Loads the last successfully loaded model path from local preferences.
final lastModelPathProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kLastModelPathKey);
});

/// Persists the last successfully loaded model path.
Future<void> saveLastModelPath(String path) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kLastModelPathKey, path);
}

/// Clears the stored “last model” path.
///
/// Call when auto-load fails to avoid retrying an invalid path on every startup.
Future<void> clearLastModelPath() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kLastModelPathKey);
}
