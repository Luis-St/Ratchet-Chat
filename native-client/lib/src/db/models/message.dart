// Message model for local database.

import 'dart:typed_data';

/// Message delivery status.
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed;

  static MessageStatus fromString(String value) {
    return MessageStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => MessageStatus.sent,
    );
  }
}

/// Represents an encrypted message.
class Message {
  final String id;
  final String conversationId;
  final String senderHandle;
  final String recipientHandle;
  final Uint8List encryptedContent;
  final DateTime timestamp;
  final MessageStatus status;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderHandle,
    required this.recipientHandle,
    required this.encryptedContent,
    required this.timestamp,
    this.status = MessageStatus.sent,
  });

  /// Create from database row.
  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderHandle: map['sender_handle'] as String,
      recipientHandle: map['recipient_handle'] as String,
      encryptedContent: map['encrypted_content'] as Uint8List,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      status: MessageStatus.fromString(map['status'] as String),
    );
  }

  /// Convert to database row.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_handle': senderHandle,
      'recipient_handle': recipientHandle,
      'encrypted_content': encryptedContent,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status.name,
    };
  }

  /// Create a copy with updated status.
  Message copyWith({MessageStatus? status}) {
    return Message(
      id: id,
      conversationId: conversationId,
      senderHandle: senderHandle,
      recipientHandle: recipientHandle,
      encryptedContent: encryptedContent,
      timestamp: timestamp,
      status: status ?? this.status,
    );
  }

  /// Check if this message was sent by the current user.
  bool isSentBy(String handle) => senderHandle == handle;
}
