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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/app_log_provider.dart';
import '../services/app_log_service.dart';

/// In-app log viewer (“Terminal”) for debugging and demo transparency.
///
/// The app routes `debugPrint` and selected service logs into [AppLogService].
/// This screen renders those entries with optional auto-scrolling.
class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({super.key});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _autoScroll) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final logService = ref.watch(appLogProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final entries = logService.entries;

    ref.listen<AppLogService>(appLogProvider, (prev, next) {
      _scrollToBottom();
    });
    // Initial scroll to bottom when opening
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        foregroundColor: const Color(0xFFE0E0E0),
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.terminal, size: 22, color: const Color(0xFF4EC9B0)),
            const SizedBox(width: 10),
            Text(
              'Terminal',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: const Color(0xFFE0E0E0),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _autoScroll = !_autoScroll);
            },
            icon: Icon(
              _autoScroll ? Icons.lock : Icons.lock_open,
              color: _autoScroll ? const Color(0xFF4EC9B0) : colorScheme.onSurfaceVariant,
            ),
            tooltip: _autoScroll ? 'Auto-scroll on' : 'Auto-scroll off',
          ),
          IconButton(
            onPressed: () {
              logService.clear();
            },
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFF252526),
            child: Row(
              children: [
                Text(
                  'App logs · ${entries.length} lines',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF858585),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'No logs yet.\nActivity will appear here.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.robotoMono(
                        fontSize: 14,
                        color: const Color(0xFF858585),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final e = entries[index];
                      Color textColor = const Color(0xFFD4D4D4);
                      if (e.level == LogLevel.error) {
                        textColor = const Color(0xFFF48771);
                      } else if (e.level == LogLevel.warn) {
                        textColor = const Color(0xFFDCDCAA);
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: SelectableText.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '[${e.formattedTime}] ',
                                style: GoogleFonts.robotoMono(
                                  fontSize: 12,
                                  color: const Color(0xFF858585),
                                ),
                              ),
                              TextSpan(
                                text: e.message,
                                style: GoogleFonts.robotoMono(
                                  fontSize: 13,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
