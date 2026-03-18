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
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/chat_message.dart';

/// Renders a single chat message as a styled bubble.
///
/// Supports:
/// - User vs assistant styling
/// - Copy-to-clipboard for assistant messages (tap icon or long-press)
/// - Optional “streaming” mode for partial assistant output
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message, this.isStreaming = false});

  /// Message to render.
  final ChatMessage message;

  /// When `true`, copy actions are disabled and empty content shows an ellipsis.
  final bool isStreaming;

  /// Copies [text] to clipboard and shows a confirmation snackbar.
  Future<void> _copyToClipboard(BuildContext context, String text) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied to clipboard', style: GoogleFonts.plusJakartaSans()),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final canCopy = !isUser && message.content.isNotEmpty && !isStreaming;
    final content = message.content.isEmpty
        ? (isStreaming ? '…' : '')
        : message.content;
    final colorScheme = Theme.of(context).colorScheme;

    Widget bubble = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isUser ? colorScheme.primary : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 6),
          bottomRight: Radius.circular(isUser ? 6 : 20),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: isUser ? 0.12 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.82,
      ),
      child: canCopy
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    content,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      height: 1.5,
                      color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.clip,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _copyToClipboard(context, message.content),
                  icon: Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            )
          : Text(
              content,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                height: 1.5,
                color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
              softWrap: true,
              overflow: TextOverflow.clip,
            ),
    );

    if (canCopy) {
      bubble = GestureDetector(
        onLongPress: () => _copyToClipboard(context, message.content),
        child: bubble,
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: bubble,
    );
  }
}
