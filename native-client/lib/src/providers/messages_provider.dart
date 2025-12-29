// Messages state management with encryption.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../api/api.dart';
import '../crypto/crypto.dart';
import '../db/db.dart';
import 'auth_provider.dart';
import 'contacts_provider.dart';

/// Decrypted message for display.
class DecryptedMessage {
  final String id;
  final String conversationId;
  final String senderHandle;
  final String recipientHandle;
  final String content;
  final DateTime timestamp;
  final MessageStatus status;
  final bool isOutgoing;

  DecryptedMessage({
    required this.id,
    required this.conversationId,
    required this.senderHandle,
    required this.recipientHandle,
    required this.content,
    required this.timestamp,
    required this.status,
    required this.isOutgoing,
  });
}

/// Messages provider for managing conversations and messages.
class MessagesProvider extends ChangeNotifier {
  final MessagesApi _messagesApi;
  final AuthProvider _authProvider;
  final ContactsProvider _contactsProvider;
  final MessageDao _messageDao;
  final ConversationDao _conversationDao;
  final Uuid _uuid = const Uuid();

  List<Conversation> _conversations = [];
  final Map<String, List<DecryptedMessage>> _messageCache = {};
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;

  MessagesProvider({
    required MessagesApi messagesApi,
    required AuthProvider authProvider,
    required ContactsProvider contactsProvider,
    MessageDao? messageDao,
    ConversationDao? conversationDao,
  })  : _messagesApi = messagesApi,
        _authProvider = authProvider,
        _contactsProvider = contactsProvider,
        _messageDao = messageDao ?? MessageDao(),
        _conversationDao = conversationDao ?? ConversationDao();

  /// All conversations.
  List<Conversation> get conversations => List.unmodifiable(_conversations);

  /// Loading state.
  bool get isLoading => _isLoading;

  /// Sending state.
  bool get isSending => _isSending;

  /// Last error.
  String? get error => _error;

  // ============== State Management ==============

  void _setLoading(bool loading) {
    _isLoading = loading;
    _error = null;
    notifyListeners();
  }

  void _setError(String error) {
    _isLoading = false;
    _isSending = false;
    _error = error;
    notifyListeners();
  }

  // ============== Initialization ==============

  /// Load conversations from local database.
  Future<void> loadConversations() async {
    _setLoading(true);

    try {
      _conversations = await _conversationDao.getAllConversations();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load conversations: $e');
    }
  }

  // ============== Messages ==============

  /// Get messages for a conversation (decrypted).
  Future<List<DecryptedMessage>> getMessages(String conversationId, {int limit = 50, int offset = 0}) async {
    // Check cache
    if (_messageCache.containsKey(conversationId) && offset == 0) {
      return _messageCache[conversationId]!;
    }

    try {
      final encryptionKey = _authProvider.state.encryptionKey;
      if (encryptionKey == null) {
        throw StateError('Not authenticated');
      }

      final myHandle = _authProvider.state.handle;
      final messages = await _messageDao.getMessagesForConversation(
        conversationId,
        limit: limit,
        offset: offset,
      );

      final decrypted = <DecryptedMessage>[];
      for (final msg in messages) {
        try {
          final plaintext = AesGcm.decrypt(msg.encryptedContent, encryptionKey);
          final content = utf8.decode(plaintext);

          decrypted.add(DecryptedMessage(
            id: msg.id,
            conversationId: msg.conversationId,
            senderHandle: msg.senderHandle,
            recipientHandle: msg.recipientHandle,
            content: content,
            timestamp: msg.timestamp,
            status: msg.status,
            isOutgoing: msg.senderHandle == myHandle,
          ));
        } catch (e) {
          // Skip messages that fail to decrypt
          debugPrint('Failed to decrypt message ${msg.id}: $e');
        }
      }

      // Cache if first page
      if (offset == 0) {
        _messageCache[conversationId] = decrypted;
      }

      return decrypted;
    } catch (e) {
      _setError('Failed to load messages: $e');
      return [];
    }
  }

  /// Clear message cache for a conversation.
  void clearCache(String conversationId) {
    _messageCache.remove(conversationId);
  }

  // ============== Send Message ==============

  /// Send an encrypted message.
  Future<bool> sendMessage(String recipientHandle, String content) async {
    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      final myHandle = _authProvider.state.handle;
      final identityKeys = _authProvider.state.identityKeys;
      final encryptionKey = _authProvider.state.encryptionKey;

      if (myHandle == null || identityKeys == null || encryptionKey == null) {
        throw StateError('Not authenticated');
      }

      // Get recipient's transport public key
      final contact = await _contactsProvider.getContactByHandle(recipientHandle);
      if (contact == null || contact.transportPublicKey == null) {
        throw StateError('Contact not found or missing transport key');
      }

      // Generate message ID
      final messageId = _uuid.v4();
      final timestamp = DateTime.now();

      // Create message payload
      final payload = {
        'id': messageId,
        'from': myHandle,
        'to': recipientHandle,
        'content': content,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

      // Sign with identity key
      final payloadBytes = utf8.encode(jsonEncode(payload));
      final signature = MlDsa65.sign(
        Uint8List.fromList(payloadBytes),
        identityKeys.secretKey,
      );

      // Add signature to payload
      final signedPayload = {
        ...payload,
        'signature': base64Encode(signature),
      };

      // Encapsulate with recipient's transport key
      final encap = MlKem768.encapsulate(contact.transportPublicKey!);

      // Encrypt payload with shared secret
      final encryptedPayload = AesGcm.encrypt(
        Uint8List.fromList(utf8.encode(jsonEncode(signedPayload))),
        encap.sharedSecret,
      );

      // Send to server
      await _messagesApi.sendMessage(SendMessageRequest(
        recipientHandle: recipientHandle,
        encapsulatedKey: base64Encode(encap.ciphertext),
        ciphertext: base64Encode(encryptedPayload),
      ));

      // Store locally (encrypted with local key)
      final localEncrypted = AesGcm.encrypt(
        Uint8List.fromList(utf8.encode(content)),
        encryptionKey,
      );

      // Get or create conversation
      final conversation = await _conversationDao.getOrCreateConversation(recipientHandle);

      // Save message
      final message = Message(
        id: messageId,
        conversationId: conversation.id,
        senderHandle: myHandle,
        recipientHandle: recipientHandle,
        encryptedContent: localEncrypted,
        timestamp: timestamp,
        status: MessageStatus.sent,
      );
      await _messageDao.insertMessage(message);

      // Update conversation
      await _conversationDao.updateLastMessage(
        conversationId: conversation.id,
        messageId: messageId,
        preview: _truncate(content, 50),
        time: timestamp,
      );

      // Clear cache and reload
      clearCache(conversation.id);
      await loadConversations();

      _isSending = false;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to send message: $e');
      return false;
    }
  }

  // ============== Receive Messages ==============

  /// Fetch and process messages from the queue.
  Future<int> fetchAndProcessQueue() async {
    _setLoading(true);

    try {
      final transportKeys = _authProvider.state.transportKeys;
      final encryptionKey = _authProvider.state.encryptionKey;
      final myHandle = _authProvider.state.handle;

      if (transportKeys == null || encryptionKey == null || myHandle == null) {
        throw StateError('Not authenticated');
      }

      // Fetch queue
      final queue = await _messagesApi.getQueue();
      var processed = 0;

      for (final incoming in queue) {
        try {
          // Decapsulate shared secret
          final sharedSecret = MlKem768.decapsulate(
            base64Decode(incoming.encapsulatedKey),
            transportKeys.secretKey,
          );

          // Decrypt payload
          final decrypted = AesGcm.decrypt(
            base64Decode(incoming.ciphertext),
            sharedSecret,
          );
          final payload = jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>;

          // Verify signature
          final senderHandle = payload['from'] as String;
          final sender = await _contactsProvider.getContactByHandle(senderHandle);

          if (sender?.identityPublicKey != null) {
            final signature = base64Decode(payload['signature'] as String);
            final messageData = Map<String, dynamic>.from(payload);
            messageData.remove('signature');

            final isValid = MlDsa65.verify(
              Uint8List.fromList(utf8.encode(jsonEncode(messageData))),
              signature,
              sender!.identityPublicKey!,
            );

            if (!isValid) {
              debugPrint('Invalid signature from $senderHandle');
              continue;
            }
          }

          // Re-encrypt with local key
          final content = payload['content'] as String;
          final localEncrypted = AesGcm.encrypt(
            Uint8List.fromList(utf8.encode(content)),
            encryptionKey,
          );

          // Store in vault via API
          await _messagesApi.storeMessage(
            messageId: incoming.id,
            encryptedContent: base64Encode(localEncrypted),
          );

          // Get or create conversation
          final conversation = await _conversationDao.getOrCreateConversation(senderHandle);

          // Save message locally
          final message = Message(
            id: payload['id'] as String,
            conversationId: conversation.id,
            senderHandle: senderHandle,
            recipientHandle: myHandle,
            encryptedContent: localEncrypted,
            timestamp: DateTime.fromMillisecondsSinceEpoch(payload['timestamp'] as int),
            status: MessageStatus.delivered,
          );
          await _messageDao.insertMessage(message);

          // Update conversation
          await _conversationDao.updateLastMessage(
            conversationId: conversation.id,
            messageId: message.id,
            preview: _truncate(content, 50),
            time: message.timestamp,
          );
          await _conversationDao.incrementUnreadCount(conversation.id);

          // Clear cache
          clearCache(conversation.id);

          processed++;
        } catch (e) {
          debugPrint('Failed to process message ${incoming.id}: $e');
        }
      }

      // Reload conversations
      await loadConversations();

      _isLoading = false;
      notifyListeners();
      return processed;
    } catch (e) {
      _setError('Failed to fetch queue: $e');
      return 0;
    }
  }

  // ============== Conversation Management ==============

  /// Mark a conversation as read.
  Future<void> markAsRead(String conversationId) async {
    await _conversationDao.markAsRead(conversationId);
    await loadConversations();
  }

  /// Delete a conversation and all its messages.
  Future<void> deleteConversation(String conversationId) async {
    await _conversationDao.deleteConversation(conversationId);
    _messageCache.remove(conversationId);
    await loadConversations();
  }

  /// Get total unread count.
  Future<int> getTotalUnreadCount() async {
    return await _conversationDao.getTotalUnreadCount();
  }

  // ============== Helpers ==============

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }
}
