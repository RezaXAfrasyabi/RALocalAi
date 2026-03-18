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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

const _nativeChannel = MethodChannel('com.rezaafrasyabi.ralocalai/native');

/// Loads a small set of device diagnostics for display in the drawer.
///
/// This is Android-only. For other platforms, returns `N/A` placeholders.
Future<Map<String, String>> loadDeviceInfo() async {
  final map = <String, String>{};
  if (!Platform.isAndroid) {
    map['phone'] = 'N/A';
    map['cpu'] = 'N/A';
    map['ram'] = 'N/A';
    map['storage'] = 'N/A';
    return map;
  }
  try {
    final native =
        await _nativeChannel.invokeMapMethod<String, dynamic>('getDeviceInfo');
    if (native != null) {
      map['phone'] = (native['phone']?.toString() ?? '').trim();
      if ((map['phone'] ?? '').isEmpty) map['phone'] = 'Android device';
      if (native['cpu'] != null) {
        map['cpu'] = native['cpu'].toString();
      }
      final totalRam = native['totalRamMb'];
      final availRam = native['availRamMb'];
      if (totalRam != null) {
        map['ram'] =
            '$totalRam MB total, ${availRam ?? '?'} MB free';
      }
      final totalSt = native['totalStorageMb'];
      final availSt = native['availStorageMb'];
      if (totalSt != null) {
        map['storage'] =
            '$totalSt MB total, ${availSt ?? '?'} MB free';
      }
    } else {
      map['phone'] = 'Android device';
      map['cpu'] = '—';
      map['ram'] = '—';
      map['storage'] = '—';
    }
  } catch (_) {
    map['phone'] = (map['phone'] ?? '').isNotEmpty ? map['phone']! : 'Android device';
    map['cpu'] = map['cpu'] ?? '—';
    map['ram'] = map['ram'] ?? '—';
    map['storage'] = map['storage'] ?? '—';
  }
  return map;
}

/// Builds a single row for the device info section in the drawer UI.
Widget deviceInfoRow(BuildContext context, String label, String value) {
  final colorScheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: RichText(
      text: TextSpan(
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: colorScheme.onSurface,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}
