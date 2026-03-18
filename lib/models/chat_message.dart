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

/// A single chat message (user or assistant).
class ChatMessage {
  /// Stable identifier for this message.
  final String id;

  /// Whether this message was authored by the user.
  final bool isUser;

  /// Plain text content displayed in the chat UI.
  final String content;

  /// Creates a chat message.
  const ChatMessage({
    required this.id,
    required this.isUser,
    required this.content,
  });

  /// Serializes this message to JSON for persistence.
  Map<String, dynamic> toJson() => {
        'id': id,
        'isUser': isUser,
        'content': content,
      };

  /// Deserializes a message previously produced by [toJson].
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
      content: json['content'] as String? ?? '',
    );
  }
}
