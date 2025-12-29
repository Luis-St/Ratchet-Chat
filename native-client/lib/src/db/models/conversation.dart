// Conversation model for local database.

/// Represents a conversation with another user.
class Conversation {
  final String id;
  final String participantHandle;
  final String? lastMessageId;
  final String? lastMessagePreview;
  final DateTime? lastMessageTime;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.participantHandle,
    this.lastMessageId,
    this.lastMessagePreview,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  /// Create from database row.
  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      participantHandle: map['participant_handle'] as String,
      lastMessageId: map['last_message_id'] as String?,
      lastMessagePreview: map['last_message_preview'] as String?,
      lastMessageTime: map['last_message_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_message_time'] as int)
          : null,
      unreadCount: (map['unread_count'] as int?) ?? 0,
    );
  }

  /// Convert to database row.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participant_handle': participantHandle,
      'last_message_id': lastMessageId,
      'last_message_preview': lastMessagePreview,
      'last_message_time': lastMessageTime?.millisecondsSinceEpoch,
      'unread_count': unreadCount,
    };
  }

  /// Create a copy with updated fields.
  Conversation copyWith({
    String? lastMessageId,
    String? lastMessagePreview,
    DateTime? lastMessageTime,
    int? unreadCount,
  }) {
    return Conversation(
      id: id,
      participantHandle: participantHandle,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  /// Check if conversation has unread messages.
  bool get hasUnread => unreadCount > 0;
}
