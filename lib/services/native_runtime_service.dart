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

/// Legacy native runtime helpers (deprecated).
///
/// This project previously supported downloading/extracting a native runtime at
/// app startup. With `flutter_llama`, the native runtime is packaged with the
/// plugin, so runtime download/extraction is no longer required.
///
/// These stubs remain only to keep older UI code compiling.

/// Deprecated: runtime ZIP download URL (no longer used).
@Deprecated('flutter_llama bundles the native runtime; no download is required.')
const String kNativeLibsZipUrl = '';

/// Deprecated: extraction is a no-op and always returns `null`.
@Deprecated('flutter_llama bundles the native runtime; no extraction is required.')
Future<String?> extractBundledNativeRuntime(void Function(String) onProgress) async {
  onProgress('Native runtime is bundled with flutter_llama; no extra download needed.');
  return null;
}

/// Deprecated: runtime download/extraction is unsupported and will throw.
@Deprecated('flutter_llama bundles the native runtime; no download is required.')
Future<String> downloadAndExtractNativeRuntime({
  required String url,
  required void Function(String) onProgress,
}) async {
  onProgress('Native runtime download is no longer used.');
  throw Exception('Runtime download is not required when using flutter_llama.');
}

