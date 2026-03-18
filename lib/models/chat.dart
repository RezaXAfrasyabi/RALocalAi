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

import 'chat_message.dart';

/// A conversation: list of messages with a title and id.
class Chat {
  /// Unique chat identifier.
  final String id;

  /// User-facing title shown in the drawer.
  final String title;

  /// Ordered list of messages in this chat.
  final List<ChatMessage> messages;

  /// Creation timestamp used for sorting chats.
  final DateTime createdAt;

  /// Creates a chat.
  Chat({
    required this.id,
    required this.title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
  })  : messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now();

  /// Returns a modified copy of this chat.
  Chat copyWith({
    String? id,
    String? title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
  }) {
    return Chat(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Serializes this chat to JSON for persistence.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  /// Deserializes a chat previously produced by [toJson].
  factory Chat.fromJson(Map<String, dynamic> json) {
    final messagesList = json['messages'] as List<dynamic>?;
    return Chat(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'New chat',
      messages: messagesList != null
          ? messagesList
              .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
