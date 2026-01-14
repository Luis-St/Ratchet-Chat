import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/contact.dart';
import '../data/repositories/message_repository.dart';
import '../data/services/socket_service.dart';
import 'auth_provider.dart';
import 'contacts_provider.dart';
import 'messages_provider.dart';
import 'service_providers.dart';
import 'socket_provider.dart';

/// TTL-based deduplication cache for socket events.
/// Prevents duplicate processing of the same event within a time window.
class _DeduplicationCache {
  static const _ttlMs = 5 * 60 * 1000; // 5 minutes
  static const _maxSize = 1000;

  final _cache = LinkedHashMap<String, int>();

  /// Returns true if the key was already processed (duplicate).
  bool isDuplicate(String key) {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Clean expired entries
    _cache.removeWhere((_, timestamp) => now - timestamp > _ttlMs);

    // Check if already processed
    if (_cache.containsKey(key)) {
      return true;
    }

    // Add to cache
    _cache[key] = now;

    // Trim if too large
    while (_cache.length > _maxSize) {
      _cache.remove(_cache.keys.first);
    }

    return false;
  }

  void clear() {
    _cache.clear();
  }
}

/// State for message sync.
class SyncState {
  final bool isSyncing;
  final DateTime? lastSyncAt;
  final String? error;

  const SyncState({
    this.isSyncing = false,
    this.lastSyncAt,
    this.error,
  });

  SyncState copyWith({
    bool? isSyncing,
    DateTime? lastSyncAt,
    String? error,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      error: error,
    );
  }
}

/// Notifier for managing message synchronization.
class SyncNotifier extends Notifier<SyncState> {
  late MessageRepository _messageRepository;
  StreamSubscription<AsyncValue<IncomingMessageEvent>>? _incomingSubscription;
  Timer? _periodicSyncTimer;
  final _dedupeCache = _DeduplicationCache();

  @override
  SyncState build() {
    _messageRepository = ref.watch(messageRepositoryProvider);

    // Listen to auth state
    final authState = ref.watch(authProvider);

    if (authState.isAuthenticated) {
      // Listen for incoming message events
      ref.listen(incomingMessageEventsProvider, (previous, next) {
        next.whenData((event) {
          _handleIncomingMessageEvent(event);
        });
      });

      // Initial sync
      _initialSync();

      // Start periodic sync (every 60 seconds as backup)
      _periodicSyncTimer?.cancel();
      _periodicSyncTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => processQueue(),
      );
    } else {
      _periodicSyncTimer?.cancel();
    }

    ref.onDispose(() {
      _incomingSubscription?.cancel();
      _periodicSyncTimer?.cancel();
    });

    return const SyncState();
  }

  Future<void> _initialSync() async {
    await processQueue();
    await syncVault();
  }

  void _handleIncomingMessageEvent(IncomingMessageEvent event) {
    // Deduplicate events to prevent double processing
    final dedupeKey = 'msg:${event.queueItemId}';
    if (_dedupeCache.isDuplicate(dedupeKey)) {
      return;
    }

    // Process the queue when we get notified of a new message
    processQueue();
  }

  /// Processes the incoming message queue.
  Future<void> processQueue() async {
    final authNotifier = ref.read(authProvider.notifier);
    final session = authNotifier.session;
    final decryptedKeys = authNotifier.decryptedKeys;
    final masterKey = authNotifier.masterKey;

    if (session == null || decryptedKeys == null || masterKey == null) return;

    state = state.copyWith(isSyncing: true);

    try {
      final contactsState = ref.read(contactsProvider);
      final apiService = ref.read(apiServiceProvider);

      // Cache for directory lookups to avoid repeated API calls
      final directoryCache = <String, Contact?>{};

      Future<Contact?> lookupContact(String handle) async {
        // First, try to find in local contacts
        try {
          return contactsState.contacts.firstWhere(
            (c) => c.handle == handle,
          );
        } catch (_) {
          // Contact not found locally
        }

        // Check cache for directory lookups
        if (directoryCache.containsKey(handle)) {
          return directoryCache[handle];
        }

        // Fall back to directory API
        try {
          final directoryEntry = await apiService.lookupDirectory(handle);
          if (directoryEntry != null) {
            final contact = Contact(
              handle: directoryEntry['handle'] as String? ?? handle,
              username: directoryEntry['display_name'] as String? ??
                        directoryEntry['username'] as String? ?? '',
              host: directoryEntry['host'] as String? ?? '',
              publicIdentityKey: directoryEntry['public_identity_key'] as String? ?? '',
              publicTransportKey: directoryEntry['public_transport_key'] as String? ?? '',
              createdAt: DateTime.now(), // Temporary contact from directory
            );
            directoryCache[handle] = contact;
            return contact;
          }
        } catch (_) {
          // Directory lookup failed
        }

        directoryCache[handle] = null;
        return null;
      }

      final messages = await _messageRepository.processQueue(
        ownerId: session.userId,
        transportPrivateKey: decryptedKeys.transportPrivateKey,
        masterKey: masterKey,
        lookupContact: lookupContact,
      );

      // Update UI with new messages
      for (final message in messages) {
        ref.read(messagesProvider.notifier).handleIncomingMessage(message);
        ref.read(conversationsProvider.notifier).updateWithNewMessage(message);
      }

      state = state.copyWith(
        isSyncing: false,
        lastSyncAt: DateTime.now(),
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: 'Queue sync failed: ${e.toString()}',
      );
    }
  }

  /// Syncs messages from the vault.
  Future<void> syncVault() async {
    final authNotifier = ref.read(authProvider.notifier);
    final session = authNotifier.session;
    final masterKey = authNotifier.masterKey;

    if (session == null || masterKey == null) return;

    state = state.copyWith(isSyncing: true);

    try {
      await _messageRepository.syncVault(
        ownerId: session.userId,
        masterKey: masterKey,
      );

      // Refresh conversations after vault sync
      await ref.read(conversationsProvider.notifier).refreshConversations();

      state = state.copyWith(
        isSyncing: false,
        lastSyncAt: DateTime.now(),
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: 'Vault sync failed: ${e.toString()}',
      );
    }
  }

  /// Manually triggers a full sync.
  Future<void> fullSync() async {
    await processQueue();
    await syncVault();
  }

  /// Clears any error.
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for sync state.
final syncProvider = NotifierProvider<SyncNotifier, SyncState>(
  SyncNotifier.new,
);
