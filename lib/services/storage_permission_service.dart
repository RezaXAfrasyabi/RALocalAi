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

import 'package:permission_handler/permission_handler.dart';

/// Storage permission helpers for model downloads.
///
/// This app stores downloaded GGUF models in a shared folder so users can keep
/// large files outside the app sandbox.
///
/// Android behavior:
/// - Requests `Permission.storage` first
/// - On Android 11+ requests `Permission.manageExternalStorage` (“All files”)
/// - May deep-link the user to Settings when permission is permanently denied
Future<bool> requestStoragePermissionForDownloads() async {
  if (!Platform.isAndroid) return true;

  // Android 9 and below: WRITE_EXTERNAL_STORAGE
  var status = await Permission.storage.status;
  if (!status.isGranted) {
    status = await Permission.storage.request();
  }
  if (status.isPermanentlyDenied) {
    await openAppSettings();
    return false;
  }

  // Android 11+ (API 30+): need "All files" to use /storage/emulated/0/...
  final manageStatus = await Permission.manageExternalStorage.status;
  if (!manageStatus.isGranted) {
    await Permission.manageExternalStorage.request();
  }
  final hasAccess = await hasStoragePermissionForDownloads();
  if (!hasAccess) {
    await openAppSettings();
    return false;
  }
  return true;
}

/// Returns `true` when the app has enough permission to read/write downloads.
///
/// On Android 11+ this requires `manageExternalStorage`; on older Android,
/// `storage` is sufficient.
Future<bool> hasStoragePermissionForDownloads() async {
  if (!Platform.isAndroid) return true;
  final manage = await Permission.manageExternalStorage.isGranted;
  if (manage) return true;
  final storage = await Permission.storage.isGranted;
  return storage;
}
