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

import 'package:flutter/services.dart';

const _nativeChannel = MethodChannel('com.rezaafrasyabi.ralocalai/native');

/// Returns total device RAM in GB.
///
/// This is Android-only and depends on a platform channel implementation.
/// Returns `null` when unavailable (non-Android, missing channel, or errors).
Future<double?> getDeviceRamGb() async {
  if (!Platform.isAndroid) return null;
  try {
    final native =
        await _nativeChannel.invokeMapMethod<String, dynamic>('getDeviceInfo');
    final totalRamMb = native?['totalRamMb'];
    if (totalRamMb == null) return null;
    final mb = totalRamMb is int ? totalRamMb : int.tryParse(totalRamMb.toString());
    if (mb == null) return null;
    return mb / 1024.0;
  } catch (_) {
    return null;
  }
}
