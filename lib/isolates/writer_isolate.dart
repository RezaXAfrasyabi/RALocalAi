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
import 'dart:isolate';

/// Isolate entry: receives destPath (String), then chunks (List of int), then null to flush/close.
void writerIsolateEntry(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  String? destPath;
  IOSink? sink;

  receivePort.listen((message) {
    if (message is String) {
      destPath = message;
      sink = File(message).openWrite();
    } else if (message is List<int>) {
      sink?.add(message);
    } else if (message == null) {
      final path = destPath;
      final s = sink;
      sink = null;
      if (s != null) {
        s.flush().then((_) => s.close()).then((_) {
          if (path != null) mainSendPort.send(path);
          receivePort.close();
        });
      } else {
        if (path != null) mainSendPort.send(path);
        receivePort.close();
      }
    }
  });
}
