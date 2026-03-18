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

import '../services/app_log_service.dart';

/// Riverpod provider exposing the global [AppLogService] instance.
///
/// This intentionally shares the instance created in `main()` so logs captured
/// before `ProviderScope` is mounted remain visible in the Terminal screen.
final appLogProvider = ChangeNotifierProvider<AppLogService>((ref) => appLogService);
