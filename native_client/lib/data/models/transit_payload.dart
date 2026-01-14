import 'dart:convert';

/// Attachment data for messages
class Attachment {
  final String filename;
  final String mimeType;
  final int size;
  final String? data; // Base64 encoded data (for small files)
  final String? url;  // URL for larger files

  Attachment({
    required this.filename,
    required this.mimeType,
    required this.size,
    this.data,
    this.url,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      filename: json['filename'] as String? ?? 'unknown',
      mimeType: json['mimeType'] as String? ?? json['mime_type'] as String? ?? 'application/octet-stream',
      size: json['size'] as int? ?? 0,
      data: json['data'] as String?,
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'mimeType': mimeType,
      'size': size,
      if (data != null) 'data': data,
      if (url != null) 'url': url,
    };
  }
}

/// Payload sent through transit (encrypted with recipient's transport key)
class TransitPayload {
  /// Message content (text)
  final String content;

  /// Sender's handle (e.g., "user@server.com")
  final String senderHandle;

  /// Signature of the message content (ML-DSA-65)
  final String senderSignature;

  /// Sender's public identity key (ML-DSA-65, base64)
  final String senderIdentityKey;

  /// Unique message ID
  final String messageId;

  /// Event type: "message", "edit", "delete", "reaction", "receipt"
  final String type;

  /// Reply context (optional)
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSenderHandle;

  /// For edit events - the new content
  final String? editedContent;

  /// For reaction events
  final String? reactionEmoji;
  final String? reactionAction; // "add" or "remove"

  /// For receipt events
  final String? receiptType; // "read" or "delivered"

  /// File attachments
  final List<Attachment>? attachments;

  TransitPayload({
    required this.content,
    required this.senderHandle,
    required this.senderSignature,
    required this.senderIdentityKey,
    required this.messageId,
    this.type = 'message',
    this.replyToMessageId,
    this.replyToText,
    this.replyToSenderHandle,
    this.editedContent,
    this.reactionEmoji,
    this.reactionAction,
    this.receiptType,
    this.attachments,
  });

  factory TransitPayload.fromJson(Map<String, dynamic> json) {
    // Parse attachments if present
    List<Attachment>? attachments;
    final attachmentsJson = json['attachments'] as List<dynamic>?;
    if (attachmentsJson != null) {
      attachments = attachmentsJson
          .map((a) => Attachment.fromJson(a as Map<String, dynamic>))
          .toList();
    }

    return TransitPayload(
      content: json['content'] as String? ?? '',
      senderHandle: json['sender_handle'] as String,
      senderSignature: json['sender_signature'] as String,
      senderIdentityKey: json['sender_identity_key'] as String,
      messageId: json['message_id'] as String,
      type: json['type'] as String? ?? 'message',
      replyToMessageId: json['reply_to_message_id'] as String?,
      replyToText: json['reply_to_text'] as String?,
      replyToSenderHandle: json['reply_to_sender_handle'] as String?,
      editedContent: json['edited_content'] as String?,
      reactionEmoji: json['reaction_emoji'] as String?,
      reactionAction: json['reaction_action'] as String?,
      receiptType: json['receipt_type'] as String?,
      attachments: attachments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'sender_handle': senderHandle,
      'sender_signature': senderSignature,
      'sender_identity_key': senderIdentityKey,
      'message_id': messageId,
      // Only include 'type' for non-message types (matching web client behavior)
      // Web client doesn't include type for regular messages
      if (type != 'message') 'type': type,
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      if (replyToText != null) 'reply_to_text': replyToText,
      if (replyToSenderHandle != null) 'reply_to_sender_handle': replyToSenderHandle,
      if (editedContent != null) 'edited_content': editedContent,
      if (reactionEmoji != null) 'reaction_emoji': reactionEmoji,
      if (reactionAction != null) 'reaction_action': reactionAction,
      if (receiptType != null) 'receipt_type': receiptType,
      if (attachments != null && attachments!.isNotEmpty)
        'attachments': attachments!.map((a) => a.toJson()).toList(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static TransitPayload fromJsonString(String jsonStr) {
    return TransitPayload.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
  }
}

/// Queue item from server's incoming queue
class QueueItem {
  final String id;
  final String encryptedBlob;
  final String senderHandle;
  final DateTime createdAt;
  final String? eventType;

  QueueItem({
    required this.id,
    required this.encryptedBlob,
    required this.senderHandle,
    required this.createdAt,
    this.eventType,
  });

  factory QueueItem.fromJson(Map<String, dynamic> json) {
    return QueueItem(
      id: json['id'] as String,
      encryptedBlob: json['encrypted_blob'] as String,
      senderHandle: json['sender_handle'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      eventType: json['event_type'] as String?,
    );
  }
}

/// Vault message from server
class VaultMessage {
  final String id;
  final String recipientId;
  final String? senderHandle;
  final String encryptedBlob;
  final String iv;
  final bool senderSignatureVerified;
  final DateTime createdAt;
  final DateTime? updatedAt;

  VaultMessage({
    required this.id,
    required this.recipientId,
    this.senderHandle,
    required this.encryptedBlob,
    required this.iv,
    required this.senderSignatureVerified,
    required this.createdAt,
    this.updatedAt,
  });

  factory VaultMessage.fromJson(Map<String, dynamic> json) {
    return VaultMessage(
      id: json['id'] as String,
      recipientId: json['recipient_id'] as String,
      senderHandle: json['sender_handle'] as String?,
      encryptedBlob: json['encrypted_blob'] as String,
      iv: json['iv'] as String,
      senderSignatureVerified: json['sender_signature_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }
}
