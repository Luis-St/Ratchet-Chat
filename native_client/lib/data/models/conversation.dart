import 'package:native_client/data/models/contact.dart';
import 'package:native_client/data/models/message.dart';

/// Represents a conversation with a contact
class Conversation {
  /// The contact for this conversation
  final Contact contact;

  /// The last message in the conversation (decrypted)
  final DecryptedMessage? lastMessage;

  /// Number of unread messages
  final int unreadCount;

  /// Last activity timestamp (for sorting)
  final DateTime? lastActivityAt;

  Conversation({
    required this.contact,
    this.lastMessage,
    required this.unreadCount,
    this.lastActivityAt,
  });

  /// Create a copy with updated fields
  Conversation copyWith({
    Contact? contact,
    DecryptedMessage? lastMessage,
    int? unreadCount,
    DateTime? lastActivityAt,
  }) {
    return Conversation(
      contact: contact ?? this.contact,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    );
  }

  /// Whether there are unread messages
  bool get hasUnread => unreadCount > 0;

  /// Get the display name for this conversation
  String get displayName => contact.effectiveDisplayName;

  /// Get a preview of the last message
  String get lastMessagePreview {
    if (lastMessage == null) return '';
    if (lastMessage!.isUnsupported) return 'Unsupported message';
    final text = lastMessage!.text ?? '';
    // Truncate if too long
    if (text.length > 50) {
      return '${text.substring(0, 50)}...';
    }
    return text;
  }

  /// Format the last activity time for display
  String formatLastActivity() {
    if (lastActivityAt == null) return '';

    final now = DateTime.now();
    final diff = now.difference(lastActivityAt!);

    if (diff.inMinutes < 1) {
      return 'now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d';
    } else {
      return '${lastActivityAt!.month}/${lastActivityAt!.day}';
    }
  }
}
