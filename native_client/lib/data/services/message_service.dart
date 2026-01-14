import 'package:native_client/data/models/transit_payload.dart';
import 'package:native_client/data/services/api_service.dart';

/// Service for message-related API operations.
class MessageService {
  final ApiService _api;

  MessageService({required ApiService api}) : _api = api;

  /// Sends an encrypted message to a recipient.
  ///
  /// Returns:
  /// - `sender_vault_stored`: Whether the message was stored in sender's vault
  /// - `timestamp`: Server timestamp
  Future<Map<String, dynamic>> sendMessage({
    required String recipientHandle,
    required String encryptedBlob,
    required String messageId,
    String eventType = 'message',
    String? encryptedPushPreview,
    String? senderVaultBlob,
    String? senderVaultIv,
    bool senderVaultSignatureVerified = true,
  }) async {
    final body = <String, dynamic>{
      'recipient_handle': recipientHandle,
      'encrypted_blob': encryptedBlob,
      'message_id': messageId,
      'event_type': eventType,
    };

    if (encryptedPushPreview != null) {
      body['encrypted_push_preview'] = encryptedPushPreview;
    }
    if (senderVaultBlob != null && senderVaultIv != null) {
      body['sender_vault_blob'] = senderVaultBlob;
      body['sender_vault_iv'] = senderVaultIv;
      body['sender_vault_signature_verified'] = senderVaultSignatureVerified;
    }

    return _api.post('/messages/send', body);
  }

  /// Fetches the incoming message queue.
  ///
  /// Returns a list of queue items to be processed.
  Future<List<QueueItem>> fetchQueue() async {
    final response = await _api.get('/messages/queue');
    final items = response['items'] as List<dynamic>? ?? [];
    return items
        .map((item) => QueueItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Acknowledges a message from the queue (marks it as processed).
  Future<void> ackQueueItem(String queueItemId) async {
    await _api.post('/messages/queue/$queueItemId/ack', {});
  }

  /// Stores a queue item in the vault after processing.
  ///
  /// This stores the decrypted and re-encrypted message in the user's vault
  /// for multi-device synchronization.
  ///
  /// Returns the stored vault item with its ID and timestamps.
  Future<VaultStoreResult> storeQueueItemInVault({
    required String queueItemId,
    required String encryptedBlob,
    required String iv,
    bool senderSignatureVerified = false,
  }) async {
    final body = <String, dynamic>{
      'encrypted_blob': encryptedBlob,
      'iv': iv,
      'sender_signature_verified': senderSignatureVerified,
    };

    final response = await _api.post('/messages/queue/$queueItemId/store', body);
    return VaultStoreResult.fromJson(response);
  }

  /// Fetches messages from the vault for a specific peer.
  ///
  /// Returns a list of vault messages.
  Future<List<VaultMessage>> fetchVaultMessages({
    required String peerHandle,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _api.get(
      '/messages/vault?peer_handle=$peerHandle&limit=$limit&offset=$offset',
    );
    final items = response['messages'] as List<dynamic>? ?? [];
    return items
        .map((item) => VaultMessage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Syncs vault changes since the given cursor.
  ///
  /// Returns:
  /// - `messages`: List of updated vault messages
  /// - `next_cursor`: Cursor for the next sync
  /// - `has_more`: Whether there are more messages to sync
  Future<VaultSyncResult> syncVault({
    String? cursor,
    int limit = 100,
  }) async {
    final queryParams = <String>[];
    if (cursor != null) {
      queryParams.add('cursor=$cursor');
    }
    queryParams.add('limit=$limit');

    final response = await _api.get('/messages/vault/sync?${queryParams.join('&')}');

    // Server returns 'items' array (matching web client)
    final items = response['items'] as List<dynamic>? ?? [];
    final messages = items
        .map((item) => VaultMessage.fromJson(item as Map<String, dynamic>))
        .toList();

    return VaultSyncResult(
      messages: messages,
      // Server uses camelCase 'nextCursor' (matching web client)
      nextCursor: response['nextCursor'] as String? ?? response['next_cursor'] as String?,
      hasMore: response['has_more'] as bool? ?? response['hasMore'] as bool? ?? false,
    );
  }

  /// Updates a vault message (for edits).
  Future<void> updateVaultMessage(String messageId, {
    String? encryptedBlob,
    String? iv,
  }) async {
    final body = <String, dynamic>{};
    if (encryptedBlob != null) {
      body['encrypted_blob'] = encryptedBlob;
    }
    if (iv != null) {
      body['iv'] = iv;
    }
    await _api.put('/messages/vault/$messageId', body);
  }

  /// Gets conversation summaries (last message per peer).
  Future<List<ConversationSummaryResponse>> getConversationSummaries() async {
    final response = await _api.get('/messages/vault/summaries');
    final items = response['summaries'] as List<dynamic>? ?? [];
    return items
        .map((item) => ConversationSummaryResponse.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

/// Result of a vault sync operation.
class VaultSyncResult {
  final List<VaultMessage> messages;
  final String? nextCursor;
  final bool hasMore;

  VaultSyncResult({
    required this.messages,
    this.nextCursor,
    required this.hasMore,
  });
}

/// Conversation summary from server.
class ConversationSummaryResponse {
  final String peerHandle;
  final String? lastMessageEncryptedBlob;
  final String? lastMessageIv;
  final DateTime? lastMessageAt;
  final int unreadCount;

  ConversationSummaryResponse({
    required this.peerHandle,
    this.lastMessageEncryptedBlob,
    this.lastMessageIv,
    this.lastMessageAt,
    required this.unreadCount,
  });

  factory ConversationSummaryResponse.fromJson(Map<String, dynamic> json) {
    return ConversationSummaryResponse(
      peerHandle: json['peer_handle'] as String,
      lastMessageEncryptedBlob: json['last_message_encrypted_blob'] as String?,
      lastMessageIv: json['last_message_iv'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}

/// Result from storing a queue item in the vault.
class VaultStoreResult {
  final String id;
  final String encryptedBlob;
  final String iv;
  final bool senderSignatureVerified;
  final DateTime createdAt;
  final DateTime? updatedAt;

  VaultStoreResult({
    required this.id,
    required this.encryptedBlob,
    required this.iv,
    required this.senderSignatureVerified,
    required this.createdAt,
    this.updatedAt,
  });

  factory VaultStoreResult.fromJson(Map<String, dynamic> json) {
    return VaultStoreResult(
      id: json['id'] as String,
      encryptedBlob: json['encrypted_blob'] as String,
      iv: json['iv'] as String,
      senderSignatureVerified: json['sender_signature_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}
