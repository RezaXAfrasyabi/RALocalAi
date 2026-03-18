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

import 'package:flutter/foundation.dart';

/// Severity level for a log entry captured by [AppLogService].
enum LogLevel { info, warn, error }

/// Single log line with a timestamp and severity.
class LogEntry {
  final DateTime time;
  final String message;
  final LogLevel level;

  /// Creates a log entry.
  const LogEntry({
    required this.time,
    required this.message,
    this.level = LogLevel.info,
  });

  /// Formats [time] as a compact `HH:mm:ss.S` string for the terminal UI.
  String get formattedTime =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}.${(time.millisecond ~/ 100).toString().padLeft(1, '0')}';
}

/// Central in-memory log buffer for the app.
///
/// This is used to provide a “Terminal” screen for observability during demos
/// and for capturing `debugPrint` output early in app startup.
class AppLogService extends ChangeNotifier {
  AppLogService();

  static const int _maxEntries = 2000;
  final List<LogEntry> _entries = [];

  /// Read-only view of all buffered log entries.
  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// Appends [message] to the log.
  ///
  /// Newlines are split into separate entries so the terminal can render them
  /// naturally without layout surprises.
  void log(String message, {LogLevel level = LogLevel.info}) {
    if (message.isEmpty) return;
    final lines = message.split('\n');
    final time = DateTime.now();
    for (final line in lines) {
      _entries.add(LogEntry(time: time, message: line, level: level));
    }
    while (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    notifyListeners();
  }

  /// Convenience helper for emitting an error-level log.
  void logError(String message) => log(message, level: LogLevel.error);

  /// Convenience helper for emitting a warning-level log.
  void logWarn(String message) => log(message, level: LogLevel.warn);

  /// Clears all buffered log entries.
  void clear() {
    _entries.clear();
    notifyListeners();
  }
}

/// Global instance used by main() to capture debugPrint before ProviderScope exists.
final appLogService = AppLogService();
