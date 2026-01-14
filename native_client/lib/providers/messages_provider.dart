import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/models/contact.dart';
import '../data/models/message.dart';
import '../data/models/conversation.dart';
import '../data/repositories/message_repository.dart';
import 'auth_provider.dart';
import 'contacts_provider.dart';
import 'service_providers.dart';
import 'socket_provider.dart';

/// Provider for the currently active conversation's peer handle.
final activeConversationProvider = StateProvider<String?>((ref) => null);

/// State for a conversation's messages.
class MessagesState {
  final List<DecryptedMessage> messages;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  const MessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  MessagesState copyWith({
    List<DecryptedMessage>? messages,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

/// Notifier for managing messages in the active conversation.
class MessagesNotifier extends Notifier<MessagesState> {
  static const int _pageSize = 50;

  late MessageRepository _messageRepository;
  String? _currentPeerHandle;
  String? _ownerId;
  Uint8List? _masterKey;

  @override
  MessagesState build() {
    _messageRepository = ref.watch(messageRepositoryProvider);

    // Listen to auth state for user info
    final authState = ref.watch(authProvider);
    _ownerId = authState.userId;
    _masterKey = ref.read(authProvider.notifier).masterKey;

    // Listen to active conversation changes
    final peerHandle = ref.watch(activeConversationProvider);
    if (peerHandle != _currentPeerHandle) {
      _currentPeerHandle = peerHandle;
      if (peerHandle != null) {
        _loadConversation(peerHandle);
      }
    }

    // Listen for incoming messages from socket
    ref.listen(socketProvider, (previous, next) {
      // Socket events are handled by the sync provider
    });

    return const MessagesState();
  }

  /// Loads messages for a conversation.
  Future<void> _loadConversation(String peerHandle) async {
    if (_ownerId == null || _masterKey == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final messages = await _messageRepository.getConversationMessages(
        ownerId: _ownerId!,
        peerHandle: peerHandle,
        masterKey: _masterKey!,
        limit: _pageSize,
      );

      state = MessagesState(
        messages: messages,
        isLoading: false,
        hasMore: messages.length >= _pageSize,
      );

      // Mark as read
      await _messageRepository.markAsRead(
        ownerId: _ownerId!,
        peerHandle: peerHandle,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load messages: ${e.toString()}',
      );
    }
  }

  /// Loads more messages (pagination).
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    if (_currentPeerHandle == null || _ownerId == null || _masterKey == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final messages = await _messageRepository.getConversationMessages(
        ownerId: _ownerId!,
        peerHandle: _currentPeerHandle!,
        masterKey: _masterKey!,
        limit: _pageSize,
        offset: state.messages.length,
      );

      state = state.copyWith(
        messages: [...state.messages, ...messages],
        isLoading: false,
        hasMore: messages.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load more messages: ${e.toString()}',
      );
    }
  }

  /// Sends a message to the current conversation.
  Future<void> sendMessage(String text) async {
    if (_currentPeerHandle == null || _ownerId == null || _masterKey == null) return;

    final authNotifier = ref.read(authProvider.notifier);
    final decryptedKeys = authNotifier.decryptedKeys;
    final session = authNotifier.session;

    if (decryptedKeys == null || session == null) return;

    // Get the contact for the recipient
    final contactsState = ref.read(contactsProvider);
    final contact = contactsState.contacts.firstWhere(
      (c) => c.handle == _currentPeerHandle,
      orElse: () => throw Exception('Contact not found'),
    );

    try {
      final message = await _messageRepository.sendMessage(
        text: text,
        recipient: contact,
        ownerId: session.userId,
        ownerHandle: session.handle,
        identityPrivateKey: decryptedKeys.identityPrivateKey,
        publicIdentityKey: session.publicIdentityKey,
        masterKey: _masterKey!,
      );

      // Add to messages list at the beginning (newest first)
      state = state.copyWith(
        messages: [message, ...state.messages],
      );

      // Update conversations list
      ref.read(conversationsProvider.notifier).refreshConversations();
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to send message: ${e.toString()}',
      );
    }
  }

  /// Handles an incoming message for the current conversation.
  void handleIncomingMessage(DecryptedMessage message) {
    if (message.peerHandle != _currentPeerHandle) return;

    // Check if message already exists
    if (state.messages.any((m) => m.id == message.id)) return;

    // Add to messages list at the beginning (newest first)
    state = state.copyWith(
      messages: [message, ...state.messages],
    );

    // Mark as read since we're viewing this conversation
    if (_ownerId != null) {
      _messageRepository.markAsRead(
        ownerId: _ownerId!,
        peerHandle: message.peerHandle,
      );
    }
  }

  /// Refreshes the current conversation.
  Future<void> refresh() async {
    if (_currentPeerHandle != null) {
      await _loadConversation(_currentPeerHandle!);
    }
  }

  /// Clears any error.
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for messages in the active conversation.
final messagesProvider = NotifierProvider<MessagesNotifier, MessagesState>(
  MessagesNotifier.new,
);

/// State for the conversations list.
class ConversationsState {
  final List<Conversation> conversations;
  final bool isLoading;
  final String? error;

  const ConversationsState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
  });

  ConversationsState copyWith({
    List<Conversation>? conversations,
    bool? isLoading,
    String? error,
  }) {
    return ConversationsState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for managing the conversations list.
class ConversationsNotifier extends Notifier<ConversationsState> {
  late MessageRepository _messageRepository;
  String? _ownerId;
  Uint8List? _masterKey;

  @override
  ConversationsState build() {
    _messageRepository = ref.watch(messageRepositoryProvider);

    // Listen to auth state
    final authState = ref.watch(authProvider);
    _ownerId = authState.userId;
    _masterKey = ref.read(authProvider.notifier).masterKey;

    // Load conversations when authenticated
    if (authState.isAuthenticated && _ownerId != null && _masterKey != null) {
      _loadConversations();
    }

    return const ConversationsState();
  }

  Future<void> _loadConversations() async {
    if (_ownerId == null || _masterKey == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final contactsState = ref.read(contactsProvider);

      Future<Contact?> lookupContact(String handle) async {
        return contactsState.contacts.firstWhere(
          (c) => c.handle == handle,
          orElse: () => Contact(
            handle: handle,
            username: handle.split('@').first,
            host: handle.contains('@') ? handle.split('@').last : '',
            publicIdentityKey: '',
            publicTransportKey: '',
            createdAt: DateTime.now(),
          ),
        );
      }

      final conversations = await _messageRepository.getConversations(
        ownerId: _ownerId!,
        masterKey: _masterKey!,
        lookupContact: lookupContact,
      );

      state = ConversationsState(
        conversations: conversations,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load conversations: ${e.toString()}',
      );
    }
  }

  /// Refreshes the conversations list.
  Future<void> refreshConversations() async {
    await _loadConversations();
  }

  /// Updates a conversation with a new message.
  void updateWithNewMessage(DecryptedMessage message) {
    final existingIndex = state.conversations.indexWhere(
      (c) => c.contact.handle == message.peerHandle,
    );

    if (existingIndex >= 0) {
      // Update existing conversation
      final updated = state.conversations[existingIndex].copyWith(
        lastMessage: message,
        lastActivityAt: message.createdAt,
        unreadCount: message.direction == MessageDirection.incoming
            ? state.conversations[existingIndex].unreadCount + 1
            : state.conversations[existingIndex].unreadCount,
      );

      final newConversations = [...state.conversations];
      newConversations.removeAt(existingIndex);
      newConversations.insert(0, updated); // Move to top

      state = state.copyWith(conversations: newConversations);
    } else {
      // Refresh to get new conversation
      refreshConversations();
    }
  }

  /// Marks a conversation as read.
  Future<void> markAsRead(String peerHandle) async {
    if (_ownerId == null) return;

    await _messageRepository.markAsRead(
      ownerId: _ownerId!,
      peerHandle: peerHandle,
    );

    // Update local state
    final existingIndex = state.conversations.indexWhere(
      (c) => c.contact.handle == peerHandle,
    );

    if (existingIndex >= 0) {
      final updated = state.conversations[existingIndex].copyWith(unreadCount: 0);
      final newConversations = [...state.conversations];
      newConversations[existingIndex] = updated;
      state = state.copyWith(conversations: newConversations);
    }
  }

  /// Gets the total unread count.
  int get totalUnreadCount {
    return state.conversations.fold(0, (sum, c) => sum + c.unreadCount);
  }

  /// Clears any error.
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for conversations list.
final conversationsProvider = NotifierProvider<ConversationsNotifier, ConversationsState>(
  ConversationsNotifier.new,
);

/// Provider for total unread count.
final totalUnreadCountProvider = Provider<int>((ref) {
  final conversations = ref.watch(conversationsProvider);
  return conversations.conversations.fold(0, (sum, c) => sum + c.unreadCount);
});
