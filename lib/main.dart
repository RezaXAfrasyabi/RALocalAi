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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/my_app.dart';
import 'services/app_log_service.dart';

/// Application entry point.
///
/// This bootstraps the widget tree and installs a guarded zone so unexpected
/// asynchronous errors are captured and surfaced in the in-app terminal.
void main() {
  /// Capture all `debugPrint` output into the in-app terminal.
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    originalDebugPrint(message, wrapWidth: wrapWidth);
    appLogService.log(message ?? '');
  };
  appLogService.log('App started. Open Terminal from the menu to view logs.');

  runZonedGuarded(() {
    runApp(const ProviderScope(child: MyApp()));
  }, (error, stack) {
    // Avoid noise from benign “already disposed” errors coming from native/plugin
    // teardown, especially during hot restart or fast navigation.
    if (error.toString().toLowerCase().contains('disposed')) return;
    appLogService.logError('Uncaught error: $error\n$stack');
    debugPrint('Uncaught error: $error\n$stack');
  });
}
