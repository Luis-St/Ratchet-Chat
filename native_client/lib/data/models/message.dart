import 'dart:convert';

import 'package:native_client/data/models/transit_payload.dart';

/// Direction of a message (incoming or outgoing)
enum MessageDirection {
  incoming,
  outgoing;

  String toJson() => this == incoming ? 'in' : 'out';

  static MessageDirection fromJson(String value) {
    return value == 'in' ? MessageDirection.incoming : MessageDirection.outgoing;
  }
}

/// Type of message
enum MessageType {
  message,
  edit,
  delete,
  reaction,
  receipt,
  unsupported;

  String toJson() => name;

  static MessageType fromJson(String value) {
    return MessageType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageType.unsupported,
    );
  }
}

/// Decrypted message content
class MessageContent {
  final String? text;
  final String direction;
  final String peerHandle;
  final String timestamp;
  final String? messageId;
  final MessageType type;
  final String? editedAt;
  final String? deletedAt;
  final String? reactionEmoji;
  final String? reactionAction;
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSenderHandle;
  // Receipt timestamps (for outgoing messages)
  final String? deliveredAt;
  final String? processedAt;
  final String? readAt;
  // File attachments
  final List<Attachment>? attachments;

  MessageContent({
    this.text,
    required this.direction,
    required this.peerHandle,
    required this.timestamp,
    this.messageId,
    this.type = MessageType.message,
    this.editedAt,
    this.deletedAt,
    this.reactionEmoji,
    this.reactionAction,
    this.replyToMessageId,
    this.replyToText,
    this.replyToSenderHandle,
    this.deliveredAt,
    this.processedAt,
    this.readAt,
    this.attachments,
  });

  factory MessageContent.fromJson(Map<String, dynamic> json) {
    // Support both camelCase and snake_case field names (matching web client)
    return MessageContent(
      text: json['text'] as String? ?? json['content'] as String?,
      direction: json['direction'] as String,
      peerHandle: json['peerHandle'] as String? ??
                  json['peer_handle'] as String? ??
                  json['peerId'] as String? ?? '',
      timestamp: json['timestamp'] as String,
      messageId: json['message_id'] as String? ?? json['messageId'] as String?,
      type: MessageType.fromJson(json['type'] as String? ?? 'message'),
      editedAt: json['editedAt'] as String? ?? json['edited_at'] as String?,
      deletedAt: json['deletedAt'] as String? ?? json['deleted_at'] as String?,
      reactionEmoji: json['reactionEmoji'] as String? ??
                     json['reaction_emoji'] as String? ??
                     json['emoji'] as String?,
      reactionAction: json['reactionAction'] as String? ??
                      json['reaction_action'] as String? ??
                      json['action'] as String?,
      replyToMessageId: json['reply_to_message_id'] as String? ??
                        json['replyToMessageId'] as String?,
      replyToText: json['reply_to_text'] as String? ??
                   json['replyToText'] as String?,
      replyToSenderHandle: json['reply_to_sender_handle'] as String? ??
                           json['replyToSenderHandle'] as String?,
      deliveredAt: json['deliveredAt'] as String? ?? json['delivered_at'] as String?,
      processedAt: json['processedAt'] as String? ?? json['processed_at'] as String?,
      readAt: json['readAt'] as String? ?? json['read_at'] as String?,
      attachments: _parseAttachments(json['attachments']),
    );
  }

  static List<Attachment>? _parseAttachments(dynamic attachmentsJson) {
    if (attachmentsJson == null) return null;
    if (attachmentsJson is! List) return null;
    return attachmentsJson
        .map((a) => Attachment.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      if (text != null) 'text': text,
      'direction': direction,
      'peerHandle': peerHandle,
      'timestamp': timestamp,
      if (messageId != null) 'message_id': messageId,
      'type': type.toJson(),
      if (editedAt != null) 'editedAt': editedAt,
      if (deletedAt != null) 'deletedAt': deletedAt,
      if (reactionEmoji != null) 'reactionEmoji': reactionEmoji,
      if (reactionAction != null) 'reactionAction': reactionAction,
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      if (replyToText != null) 'reply_to_text': replyToText,
      if (replyToSenderHandle != null) 'reply_to_sender_handle': replyToSenderHandle,
      if (deliveredAt != null) 'deliveredAt': deliveredAt,
      if (processedAt != null) 'processedAt': processedAt,
      if (readAt != null) 'readAt': readAt,
      if (attachments != null && attachments!.isNotEmpty)
        'attachments': attachments!.map((a) => a.toJson()).toList(),
    };
  }

  /// Creates a copy with updated fields
  MessageContent copyWith({
    String? text,
    String? direction,
    String? peerHandle,
    String? timestamp,
    String? messageId,
    MessageType? type,
    String? editedAt,
    String? deletedAt,
    String? reactionEmoji,
    String? reactionAction,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderHandle,
    String? deliveredAt,
    String? processedAt,
    String? readAt,
    List<Attachment>? attachments,
  }) {
    return MessageContent(
      text: text ?? this.text,
      direction: direction ?? this.direction,
      peerHandle: peerHandle ?? this.peerHandle,
      timestamp: timestamp ?? this.timestamp,
      messageId: messageId ?? this.messageId,
      type: type ?? this.type,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      reactionEmoji: reactionEmoji ?? this.reactionEmoji,
      reactionAction: reactionAction ?? this.reactionAction,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToText: replyToText ?? this.replyToText,
      replyToSenderHandle: replyToSenderHandle ?? this.replyToSenderHandle,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      processedAt: processedAt ?? this.processedAt,
      readAt: readAt ?? this.readAt,
      attachments: attachments ?? this.attachments,
    );
  }
}

/// Encrypted payload structure (stored in database)
class EncryptedMessagePayload {
  final String encryptedBlob;
  final String iv;

  EncryptedMessagePayload({
    required this.encryptedBlob,
    required this.iv,
  });

  factory EncryptedMessagePayload.fromJson(Map<String, dynamic> json) {
    return EncryptedMessagePayload(
      encryptedBlob: json['encrypted_blob'] as String,
      iv: json['iv'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'encrypted_blob': encryptedBlob,
      'iv': iv,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static EncryptedMessagePayload fromJsonString(String jsonStr) {
    return EncryptedMessagePayload.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
  }
}

/// A decrypted message ready for display
class DecryptedMessage {
  final String id;
  final String senderId;
  final String peerHandle;
  final String? text;
  final MessageDirection direction;
  final MessageType type;
  final DateTime createdAt;
  final bool isRead;
  final bool vaultSynced;
  final bool verified;
  final String? referencedMessageId;
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSenderHandle;
  final List<Attachment>? attachments;

  DecryptedMessage({
    required this.id,
    required this.senderId,
    required this.peerHandle,
    this.text,
    required this.direction,
    required this.type,
    required this.createdAt,
    required this.isRead,
    required this.vaultSynced,
    required this.verified,
    this.referencedMessageId,
    this.replyToMessageId,
    this.replyToText,
    this.replyToSenderHandle,
    this.attachments,
  });

  /// Check if this is an unsupported message type
  bool get isUnsupported => type == MessageType.unsupported;

  /// Check if this message has attachments
  bool get hasAttachments => attachments != null && attachments!.isNotEmpty;

  /// Get display text (or placeholder for unsupported)
  String get displayText {
    if (isUnsupported) {
      return 'Unsupported message type';
    }
    if (hasAttachments && (text == null || text!.isEmpty)) {
      final count = attachments!.length;
      return count == 1 ? '📎 ${attachments!.first.filename}' : '📎 $count files';
    }
    return text ?? '';
  }

  DecryptedMessage copyWith({
    String? id,
    String? senderId,
    String? peerHandle,
    String? text,
    MessageDirection? direction,
    MessageType? type,
    DateTime? createdAt,
    bool? isRead,
    bool? vaultSynced,
    bool? verified,
    String? referencedMessageId,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderHandle,
    List<Attachment>? attachments,
  }) {
    return DecryptedMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      peerHandle: peerHandle ?? this.peerHandle,
      text: text ?? this.text,
      direction: direction ?? this.direction,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      vaultSynced: vaultSynced ?? this.vaultSynced,
      verified: verified ?? this.verified,
      referencedMessageId: referencedMessageId ?? this.referencedMessageId,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToText: replyToText ?? this.replyToText,
      replyToSenderHandle: replyToSenderHandle ?? this.replyToSenderHandle,
      attachments: attachments ?? this.attachments,
    );
  }
}
