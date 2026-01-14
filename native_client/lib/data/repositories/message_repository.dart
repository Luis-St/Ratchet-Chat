import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:native_client/data/database/app_database.dart';
import 'package:native_client/data/models/contact.dart';
import 'package:native_client/data/models/message.dart';
import 'package:native_client/data/models/conversation.dart';
import 'package:native_client/data/models/transit_payload.dart';
import 'package:native_client/data/services/message_service.dart';
import 'package:native_client/data/services/message_crypto_service.dart';

/// Repository for message operations.
///
/// Handles sending, receiving, storing, and syncing messages.
class MessageRepository {
  final AppDatabase _db;
  final MessageService _messageService;
  final MessageCryptoService _messageCrypto;
  final Uuid _uuid = const Uuid();

  MessageRepository({
    required AppDatabase db,
    required MessageService messageService,
    required MessageCryptoService messageCrypto,
  })  : _db = db,
        _messageService = messageService,
        _messageCrypto = messageCrypto;

  /// Sends a text message to a recipient.
  ///
  /// Returns the created message.
  Future<DecryptedMessage> sendMessage({
    required String text,
    required Contact recipient,
    required String ownerId,
    required String ownerHandle,
    required Uint8List identityPrivateKey,
    required String publicIdentityKey,
    required Uint8List masterKey,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderHandle,
  }) async {
    final messageId = _uuid.v4();
    final now = DateTime.now();

    // Create the encrypted transit blob for the recipient
    final encryptedTransitBlob = _messageCrypto.createEncryptedTransitBlob(
      content: text,
      senderHandle: ownerHandle,
      messageId: messageId,
      identityPrivateKey: identityPrivateKey,
      publicIdentityKey: publicIdentityKey,
      recipientPublicTransportKey: recipient.publicTransportKey,
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
      replyToSenderHandle: replyToSenderHandle,
    );

    // Create local storage content
    final localContent = MessageContent(
      text: text,
      direction: 'out',
      peerHandle: recipient.handle,
      timestamp: now.toIso8601String(),
      messageId: messageId,
      type: MessageType.message,
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
      replyToSenderHandle: replyToSenderHandle,
    );

    // Encrypt for local storage
    final encryptedLocal = _messageCrypto.encryptForLocalStorage(
      content: localContent,
      masterKey: masterKey,
    );

    // Create vault blob for sender's vault (multi-device sync)
    final vaultBlob = encryptedLocal.encryptedBlob;
    final vaultIv = encryptedLocal.iv;

    // Save to local database first
    await _db.upsertMessage(MessagesCompanion(
      id: Value(messageId),
      ownerId: Value(ownerId),
      senderId: Value(ownerHandle),
      peerHandle: Value(recipient.handle),
      encryptedContent: Value(encryptedLocal.toJsonString()),
      direction: const Value('out'),
      type: const Value('message'),
      createdAt: Value(now),
      isRead: const Value(true),
      vaultSynced: const Value(false),
      verified: const Value(true),
    ));

    // Send to server
    try {
      final response = await _messageService.sendMessage(
        recipientHandle: recipient.handle,
        encryptedBlob: encryptedTransitBlob,
        messageId: messageId,
        senderVaultBlob: vaultBlob,
        senderVaultIv: vaultIv,
      );

      // Update vault sync status if stored
      if (response['sender_vault_stored'] == true) {
        await _db.updateVaultSynced(messageId, true);
      }
    } catch (e) {
      // Message is saved locally even if send fails
      // Can retry later
      rethrow;
    }

    return DecryptedMessage(
      id: messageId,
      senderId: ownerHandle,
      peerHandle: recipient.handle,
      text: text,
      direction: MessageDirection.outgoing,
      type: MessageType.message,
      createdAt: now,
      isRead: true,
      vaultSynced: false,
      verified: true,
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
      replyToSenderHandle: replyToSenderHandle,
    );
  }

  /// Processes an incoming queue item.
  ///
  /// Decrypts, verifies, stores locally, syncs to vault, and ACKs.
  Future<DecryptedMessage?> processQueueItem({
    required QueueItem queueItem,
    required String ownerId,
    required Uint8List transportPrivateKey,
    required Uint8List masterKey,
    required Future<Contact?> Function(String handle) lookupContact,
    Set<String>? blockedHandles,
  }) async {
    // Check if sender is blocked
    if (blockedHandles?.contains(queueItem.senderHandle) ?? false) {
      // ACK and discard
      await _messageService.ackQueueItem(queueItem.id);
      return null;
    }

    // Decrypt the transit payload
    TransitPayload payload;
    try {
      payload = _messageCrypto.decryptAndParseTransitPayload(
        encryptedBlob: queueItem.encryptedBlob,
        transportPrivateKey: transportPrivateKey,
      );
    } catch (e) {
      // Invalid message, ACK to remove from queue
      await _messageService.ackQueueItem(queueItem.id);
      return null;
    }

    // Handle different message types
    if (payload.type == 'call') {
      // Call signaling is ephemeral, just ACK
      await _messageService.ackQueueItem(queueItem.id);
      return null;
    }

    if (payload.type == 'receipt') {
      // Process receipt to update target message's delivery/read status
      await _processReceipt(
        payload: payload,
        ownerId: ownerId,
        masterKey: masterKey,
        lookupContact: lookupContact,
      );
      await _messageService.ackQueueItem(queueItem.id);
      return null;
    }

    // Verify signature with TOFU (Trust On First Use) check
    final contact = await lookupContact(payload.senderHandle);
    bool verified = false;
    if (contact != null) {
      // TOFU check: inline identity key must match stored contact key
      // This prevents MITM attacks where attacker sends valid signature with different key
      final inlineKeyMatchesStored = payload.senderIdentityKey == contact.publicIdentityKey;

      if (inlineKeyMatchesStored) {
        // Keys match, verify signature with stored key
        verified = _messageCrypto.verifySignature(
          senderHandle: payload.senderHandle,
          content: payload.content,
          messageId: payload.messageId,
          signature: payload.senderSignature,
          publicIdentityKey: contact.publicIdentityKey,
        );
      }
      // If keys don't match, verified stays false (potential key impersonation)
    }

    // Determine message type
    MessageType messageType;
    switch (payload.type) {
      case 'message':
        messageType = MessageType.message;
        break;
      case 'edit':
        messageType = MessageType.edit;
        break;
      case 'delete':
        messageType = MessageType.delete;
        break;
      case 'reaction':
        messageType = MessageType.reaction;
        break;
      default:
        messageType = MessageType.unsupported;
    }

    // Create local content
    final localContent = MessageContent(
      text: payload.content,
      direction: 'in',
      peerHandle: payload.senderHandle,
      timestamp: queueItem.createdAt.toIso8601String(),
      messageId: payload.messageId,
      type: messageType,
      replyToMessageId: payload.replyToMessageId,
      replyToText: payload.replyToText,
      replyToSenderHandle: payload.replyToSenderHandle,
    );

    // Encrypt for local storage
    final encryptedLocal = _messageCrypto.encryptForLocalStorage(
      content: localContent,
      masterKey: masterKey,
    );

    // Save to local database
    await _db.upsertMessage(MessagesCompanion(
      id: Value(payload.messageId),
      ownerId: Value(ownerId),
      senderId: Value(payload.senderHandle),
      peerHandle: Value(payload.senderHandle),
      encryptedContent: Value(encryptedLocal.toJsonString()),
      direction: const Value('in'),
      type: Value(messageType.toJson()),
      createdAt: Value(queueItem.createdAt),
      isRead: const Value(false),
      vaultSynced: const Value(false),
      verified: Value(verified),
    ));

    // Store in vault (this also ACKs the queue item on the server)
    bool vaultSynced = false;
    try {
      await _messageService.storeQueueItemInVault(
        queueItemId: queueItem.id,
        encryptedBlob: encryptedLocal.encryptedBlob,
        iv: encryptedLocal.iv,
        senderSignatureVerified: verified,
      );
      await _db.updateVaultSynced(payload.messageId, true);
      vaultSynced = true;
    } catch (e) {
      // Vault store failed, ACK manually to remove from queue
      // Message is saved locally but won't sync to other devices
      try {
        await _messageService.ackQueueItem(queueItem.id);
      } catch (_) {
        // Best-effort ACK
      }
    }

    return DecryptedMessage(
      id: payload.messageId,
      senderId: payload.senderHandle,
      peerHandle: payload.senderHandle,
      text: payload.content,
      direction: MessageDirection.incoming,
      type: messageType,
      createdAt: queueItem.createdAt,
      isRead: false,
      vaultSynced: vaultSynced,
      verified: verified,
      replyToMessageId: payload.replyToMessageId,
      replyToText: payload.replyToText,
      replyToSenderHandle: payload.replyToSenderHandle,
    );
  }

  /// Fetches and processes all pending queue items.
  Future<List<DecryptedMessage>> processQueue({
    required String ownerId,
    required Uint8List transportPrivateKey,
    required Uint8List masterKey,
    required Future<Contact?> Function(String handle) lookupContact,
    Set<String>? blockedHandles,
  }) async {
    final queueItems = await _messageService.fetchQueue();
    final messages = <DecryptedMessage>[];

    for (final item in queueItems) {
      final message = await processQueueItem(
        queueItem: item,
        ownerId: ownerId,
        transportPrivateKey: transportPrivateKey,
        masterKey: masterKey,
        lookupContact: lookupContact,
        blockedHandles: blockedHandles,
      );
      if (message != null) {
        messages.add(message);
      }
    }

    return messages;
  }

  /// Gets messages for a conversation from local database.
  Future<List<DecryptedMessage>> getConversationMessages({
    required String ownerId,
    required String peerHandle,
    required Uint8List masterKey,
    int limit = 50,
    int offset = 0,
  }) async {
    final dbMessages = await _db.getConversationMessages(
      ownerId,
      peerHandle,
      limit: limit,
      offset: offset,
    );

    return _decryptMessages(dbMessages, masterKey);
  }

  /// Gets all conversations with last message.
  Future<List<Conversation>> getConversations({
    required String ownerId,
    required Uint8List masterKey,
    required Future<Contact?> Function(String handle) lookupContact,
  }) async {
    final summaries = await _db.getConversations(ownerId);
    final conversations = <Conversation>[];

    for (final summary in summaries) {
      final contact = await lookupContact(summary.peerHandle);
      if (contact == null) continue;

      // Decrypt last message
      DecryptedMessage? lastMessage;
      try {
        final encrypted = EncryptedMessagePayload.fromJsonString(
          summary.lastMessageEncryptedContent,
        );
        final content = _messageCrypto.decryptFromLocalStorage(
          encrypted: encrypted,
          masterKey: masterKey,
        );
        lastMessage = DecryptedMessage(
          id: summary.lastMessageId,
          senderId: summary.lastMessageDirection == 'out'
              ? ownerId
              : summary.peerHandle,
          peerHandle: summary.peerHandle,
          text: content.text,
          direction: MessageDirection.fromJson(summary.lastMessageDirection),
          type: content.type,
          createdAt: summary.lastMessageCreatedAt,
          isRead: true,
          vaultSynced: true,
          verified: true,
        );
      } catch (e) {
        // Failed to decrypt, skip
      }

      conversations.add(Conversation(
        contact: contact,
        lastMessage: lastMessage,
        unreadCount: summary.unreadCount,
        lastActivityAt: summary.lastMessageCreatedAt,
      ));
    }

    return conversations;
  }

  /// Marks all messages from a peer as read.
  Future<void> markAsRead({
    required String ownerId,
    required String peerHandle,
  }) async {
    await _db.markAsRead(ownerId, peerHandle);
  }

  /// Gets the unread count for a peer.
  Future<int> getUnreadCount({
    required String ownerId,
    required String peerHandle,
  }) async {
    return _db.getUnreadCount(ownerId, peerHandle);
  }

  /// Gets the total unread count across all conversations.
  Future<int> getTotalUnreadCount(String ownerId) async {
    return _db.getTotalUnreadCount(ownerId);
  }

  /// Syncs messages from the vault.
  Future<void> syncVault({
    required String ownerId,
    required Uint8List masterKey,
  }) async {
    // Get current cursor
    final cursor = await _db.getSyncCursor(ownerId, 'vault_cursor');

    // Sync from vault
    final result = await _messageService.syncVault(cursor: cursor);

    // Process synced messages
    for (final vaultMessage in result.messages) {
      try {
        final encrypted = EncryptedMessagePayload(
          encryptedBlob: vaultMessage.encryptedBlob,
          iv: vaultMessage.iv,
        );
        final content = _messageCrypto.decryptFromLocalStorage(
          encrypted: encrypted,
          masterKey: masterKey,
        );

        // Check if message already exists locally
        if (await _db.messageExists(content.messageId ?? vaultMessage.id)) {
          continue;
        }

        // Save to local database
        await _db.upsertMessage(MessagesCompanion(
          id: Value(content.messageId ?? vaultMessage.id),
          ownerId: Value(ownerId),
          senderId: Value(vaultMessage.senderHandle ?? content.peerHandle),
          peerHandle: Value(content.peerHandle),
          encryptedContent: Value(encrypted.toJsonString()),
          direction: Value(content.direction),
          type: Value(content.type.toJson()),
          createdAt: Value(vaultMessage.createdAt),
          isRead: const Value(true), // Vault messages are assumed read
          vaultSynced: const Value(true),
          verified: Value(vaultMessage.senderSignatureVerified),
        ));
      } catch (e) {
        // Failed to process vault message, skip
      }
    }

    // Update cursor if we have a new one
    if (result.nextCursor != null) {
      await _db.updateSyncCursor(ownerId, 'vault_cursor', result.nextCursor!);
    }

    // Continue syncing if there are more
    if (result.hasMore) {
      await syncVault(ownerId: ownerId, masterKey: masterKey);
    }
  }

  /// Clears all message data for an owner (on logout).
  Future<void> clearOwnerData(String ownerId) async {
    await _db.clearOwnerData(ownerId);
  }

  /// Decrypts a list of database messages.
  List<DecryptedMessage> _decryptMessages(
    List<Message> dbMessages,
    Uint8List masterKey,
  ) {
    final messages = <DecryptedMessage>[];

    for (final dbMessage in dbMessages) {
      try {
        final encrypted = EncryptedMessagePayload.fromJsonString(
          dbMessage.encryptedContent,
        );
        final content = _messageCrypto.decryptFromLocalStorage(
          encrypted: encrypted,
          masterKey: masterKey,
        );

        messages.add(DecryptedMessage(
          id: dbMessage.id,
          senderId: dbMessage.senderId,
          peerHandle: dbMessage.peerHandle,
          text: content.text,
          direction: MessageDirection.fromJson(dbMessage.direction),
          type: MessageType.fromJson(dbMessage.type),
          createdAt: dbMessage.createdAt,
          isRead: dbMessage.isRead,
          vaultSynced: dbMessage.vaultSynced,
          verified: dbMessage.verified,
          replyToMessageId: content.replyToMessageId,
          replyToText: content.replyToText,
          replyToSenderHandle: content.replyToSenderHandle,
        ));
      } catch (e) {
        // Failed to decrypt, add as unsupported
        messages.add(DecryptedMessage(
          id: dbMessage.id,
          senderId: dbMessage.senderId,
          peerHandle: dbMessage.peerHandle,
          text: null,
          direction: MessageDirection.fromJson(dbMessage.direction),
          type: MessageType.unsupported,
          createdAt: dbMessage.createdAt,
          isRead: dbMessage.isRead,
          vaultSynced: dbMessage.vaultSynced,
          verified: dbMessage.verified,
        ));
      }
    }

    return messages;
  }

  /// Processes a receipt event to update the target message's delivery/read status.
  Future<void> _processReceipt({
    required TransitPayload payload,
    required String ownerId,
    required Uint8List masterKey,
    required Future<Contact?> Function(String handle) lookupContact,
  }) async {
    // Receipt must reference a message
    final targetMessageId = payload.messageId;
    if (targetMessageId.isEmpty) return;

    // Verify the receipt signature
    final contact = await lookupContact(payload.senderHandle);
    if (contact == null) return;

    // TOFU check for receipt
    final inlineKeyMatchesStored = payload.senderIdentityKey == contact.publicIdentityKey;
    if (!inlineKeyMatchesStored) return;

    final signatureValid = _messageCrypto.verifySignature(
      senderHandle: payload.senderHandle,
      content: payload.content,
      messageId: payload.messageId,
      signature: payload.senderSignature,
      publicIdentityKey: contact.publicIdentityKey,
    );
    if (!signatureValid) return;

    // Parse the receipt content to determine type and timestamp
    // Format: "receipt:STATUS:TIMESTAMP" where STATUS is PROCESSED_BY_CLIENT or READ_BY_USER
    final receiptParts = payload.content.split(':');
    if (receiptParts.length < 3 || receiptParts[0] != 'receipt') return;

    final receiptStatus = receiptParts[1];
    final receiptTimestamp = receiptParts.sublist(2).join(':'); // Handle timestamp with colons

    // Get the target message from database
    final targetMessage = await _db.getMessageById(targetMessageId);
    if (targetMessage == null) return;

    // Only update outgoing messages (receipts are for messages we sent)
    if (targetMessage.direction != 'out') return;

    // Decrypt the current message content
    try {
      final encrypted = EncryptedMessagePayload.fromJsonString(
        targetMessage.encryptedContent,
      );
      final content = _messageCrypto.decryptFromLocalStorage(
        encrypted: encrypted,
        masterKey: masterKey,
      );

      // Update the appropriate timestamp based on receipt status
      MessageContent updatedContent;
      if (receiptStatus == 'PROCESSED_BY_CLIENT') {
        // Don't downgrade read to processed
        if (content.readAt != null) return;
        updatedContent = content.copyWith(processedAt: receiptTimestamp);
      } else if (receiptStatus == 'READ_BY_USER') {
        updatedContent = content.copyWith(readAt: receiptTimestamp);
      } else {
        return;
      }

      // Re-encrypt and save
      final newEncrypted = _messageCrypto.encryptForLocalStorage(
        content: updatedContent,
        masterKey: masterKey,
      );

      await _db.upsertMessage(MessagesCompanion(
        id: Value(targetMessage.id),
        ownerId: Value(targetMessage.ownerId),
        senderId: Value(targetMessage.senderId),
        peerHandle: Value(targetMessage.peerHandle),
        encryptedContent: Value(newEncrypted.toJsonString()),
        direction: Value(targetMessage.direction),
        type: Value(targetMessage.type),
        createdAt: Value(targetMessage.createdAt),
        isRead: Value(targetMessage.isRead),
        vaultSynced: Value(targetMessage.vaultSynced),
        verified: Value(targetMessage.verified),
      ));
    } catch (e) {
      // Failed to process receipt, ignore
    }
  }
}
