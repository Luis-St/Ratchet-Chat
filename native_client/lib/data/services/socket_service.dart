import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

/// Socket event types that match the server
class SocketEvents {
  // Message events
  static const String incomingMessage = 'INCOMING_MESSAGE';
  static const String outgoingMessageSynced = 'OUTGOING_MESSAGE_SYNCED';
  static const String incomingMessageSynced = 'INCOMING_MESSAGE_SYNCED';
  static const String vaultMessageUpdated = 'VAULT_MESSAGE_UPDATED';
  static const String signal = 'signal';

  // Sync events
  static const String transportKeyRotated = 'TRANSPORT_KEY_ROTATED';
  static const String blockListUpdated = 'BLOCK_LIST_UPDATED';
  static const String contactsUpdated = 'CONTACTS_UPDATED';
  static const String settingsUpdated = 'SETTINGS_UPDATED';
  static const String privacySettingsUpdated = 'PRIVACY_SETTINGS_UPDATED';
  static const String mutedConversationsUpdated = 'MUTED_CONVERSATIONS_UPDATED';

  // Session events
  static const String sessionInvalidated = 'SESSION_INVALIDATED';
  static const String sessionDeleted = 'SESSION_DELETED';
}

/// Data for an incoming message event
class IncomingMessageEvent {
  final String queueItemId;
  final String senderHandle;

  IncomingMessageEvent({
    required this.queueItemId,
    required this.senderHandle,
  });

  factory IncomingMessageEvent.fromJson(Map<String, dynamic> json) {
    return IncomingMessageEvent(
      queueItemId: json['queue_item_id'] as String? ?? json['id'] as String,
      senderHandle: json['sender_handle'] as String,
    );
  }
}

/// Data for a vault update event
class VaultUpdateEvent {
  final String messageId;
  final String? peerHandle;
  final int? version;
  final String? deletedAt;

  VaultUpdateEvent({
    required this.messageId,
    this.peerHandle,
    this.version,
    this.deletedAt,
  });

  factory VaultUpdateEvent.fromJson(Map<String, dynamic> json) {
    return VaultUpdateEvent(
      messageId: json['message_id'] as String? ?? json['id'] as String,
      peerHandle: json['peer_handle'] as String?,
      version: json['version'] as int?,
      deletedAt: json['deleted_at'] as String?,
    );
  }
}

/// Data for a transport key rotation event
class TransportKeyRotatedEvent {
  final String handle;
  final String publicTransportKey;
  final String? rotatedAt;

  TransportKeyRotatedEvent({
    required this.handle,
    required this.publicTransportKey,
    this.rotatedAt,
  });

  factory TransportKeyRotatedEvent.fromJson(Map<String, dynamic> json) {
    return TransportKeyRotatedEvent(
      handle: json['handle'] as String,
      publicTransportKey: json['public_transport_key'] as String,
      rotatedAt: json['rotated_at'] as String?,
    );
  }
}

/// Data for a session invalidated event
class SessionInvalidatedEvent {
  final String reason;

  SessionInvalidatedEvent({required this.reason});

  factory SessionInvalidatedEvent.fromJson(Map<String, dynamic> json) {
    return SessionInvalidatedEvent(
      reason: json['reason'] as String? ?? 'Session invalidated',
    );
  }
}

/// Data for a session deleted event
class SessionDeletedEvent {
  final String sessionId;

  SessionDeletedEvent({required this.sessionId});

  factory SessionDeletedEvent.fromJson(Map<String, dynamic> json) {
    return SessionDeletedEvent(
      sessionId: json['session_id'] as String,
    );
  }
}

/// Generic sync event (for block list, contacts, settings updates)
class SyncEvent {
  final String type;
  final Map<String, dynamic>? data;

  SyncEvent({required this.type, this.data});

  factory SyncEvent.fromJson(String type, Map<String, dynamic> json) {
    return SyncEvent(type: type, data: json);
  }
}

/// Service for real-time messaging via Socket.IO.
class SocketService {
  io.Socket? _socket;
  bool _isConnected = false;
  String? _serverUrl;
  String? _token;

  // Message event stream controllers
  final _incomingMessageController = StreamController<IncomingMessageEvent>.broadcast();
  final _outgoingMessageSyncedController = StreamController<VaultUpdateEvent>.broadcast();
  final _incomingMessageSyncedController = StreamController<VaultUpdateEvent>.broadcast();
  final _vaultMessageUpdatedController = StreamController<VaultUpdateEvent>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  // Sync event stream controllers
  final _transportKeyRotatedController = StreamController<TransportKeyRotatedEvent>.broadcast();
  final _blockListUpdatedController = StreamController<SyncEvent>.broadcast();
  final _contactsUpdatedController = StreamController<SyncEvent>.broadcast();
  final _settingsUpdatedController = StreamController<SyncEvent>.broadcast();
  final _privacySettingsUpdatedController = StreamController<SyncEvent>.broadcast();
  final _mutedConversationsUpdatedController = StreamController<SyncEvent>.broadcast();

  // Session event stream controllers
  final _sessionInvalidatedController = StreamController<SessionInvalidatedEvent>.broadcast();
  final _sessionDeletedController = StreamController<SessionDeletedEvent>.broadcast();

  /// Stream of incoming message events.
  Stream<IncomingMessageEvent> get onIncomingMessage => _incomingMessageController.stream;

  /// Stream of outgoing message synced events (from another device).
  Stream<VaultUpdateEvent> get onOutgoingMessageSynced => _outgoingMessageSyncedController.stream;

  /// Stream of incoming message synced events (from another device).
  Stream<VaultUpdateEvent> get onIncomingMessageSynced => _incomingMessageSyncedController.stream;

  /// Stream of vault message updated events.
  Stream<VaultUpdateEvent> get onVaultMessageUpdated => _vaultMessageUpdatedController.stream;

  /// Stream of connection state changes.
  Stream<bool> get onConnectionStateChange => _connectionStateController.stream;

  /// Stream of transport key rotation events.
  Stream<TransportKeyRotatedEvent> get onTransportKeyRotated => _transportKeyRotatedController.stream;

  /// Stream of block list update events.
  Stream<SyncEvent> get onBlockListUpdated => _blockListUpdatedController.stream;

  /// Stream of contacts update events.
  Stream<SyncEvent> get onContactsUpdated => _contactsUpdatedController.stream;

  /// Stream of settings update events.
  Stream<SyncEvent> get onSettingsUpdated => _settingsUpdatedController.stream;

  /// Stream of privacy settings update events.
  Stream<SyncEvent> get onPrivacySettingsUpdated => _privacySettingsUpdatedController.stream;

  /// Stream of muted conversations update events.
  Stream<SyncEvent> get onMutedConversationsUpdated => _mutedConversationsUpdatedController.stream;

  /// Stream of session invalidated events (requires logout).
  Stream<SessionInvalidatedEvent> get onSessionInvalidated => _sessionInvalidatedController.stream;

  /// Stream of session deleted events.
  Stream<SessionDeletedEvent> get onSessionDeleted => _sessionDeletedController.stream;

  /// Whether the socket is currently connected.
  bool get isConnected => _isConnected;

  /// Connects to the Socket.IO server.
  void connect(String serverUrl, String token) {
    if (_socket != null && _isConnected) {
      // Already connected, check if credentials changed
      if (_serverUrl == serverUrl && _token == token) {
        return;
      }
      // Credentials changed, disconnect first
      disconnect();
    }

    _serverUrl = serverUrl;
    _token = token;

    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    _setupEventHandlers();
    _socket!.connect();
  }

  /// Disconnects from the Socket.IO server.
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _serverUrl = null;
    _token = null;
    _connectionStateController.add(false);
  }

  /// Sets up event handlers for the socket.
  void _setupEventHandlers() {
    final socket = _socket;
    if (socket == null) return;

    socket.onConnect((_) {
      _isConnected = true;
      _connectionStateController.add(true);
    });

    socket.onDisconnect((_) {
      _isConnected = false;
      _connectionStateController.add(false);
    });

    socket.onConnectError((error) {
      _isConnected = false;
      _connectionStateController.add(false);
    });

    socket.onError((error) {
      // Handle error
    });

    // Message events
    socket.on(SocketEvents.incomingMessage, (data) {
      if (data is Map<String, dynamic>) {
        _incomingMessageController.add(IncomingMessageEvent.fromJson(data));
      }
    });

    socket.on(SocketEvents.outgoingMessageSynced, (data) {
      if (data is Map<String, dynamic>) {
        _outgoingMessageSyncedController.add(VaultUpdateEvent.fromJson(data));
      }
    });

    socket.on(SocketEvents.incomingMessageSynced, (data) {
      if (data is Map<String, dynamic>) {
        _incomingMessageSyncedController.add(VaultUpdateEvent.fromJson(data));
      }
    });

    socket.on(SocketEvents.vaultMessageUpdated, (data) {
      if (data is Map<String, dynamic>) {
        _vaultMessageUpdatedController.add(VaultUpdateEvent.fromJson(data));
      }
    });

    // Sync events
    socket.on(SocketEvents.transportKeyRotated, (data) {
      if (data is Map<String, dynamic>) {
        _transportKeyRotatedController.add(TransportKeyRotatedEvent.fromJson(data));
      }
    });

    socket.on(SocketEvents.blockListUpdated, (data) {
      final json = data is Map<String, dynamic> ? data : <String, dynamic>{};
      _blockListUpdatedController.add(SyncEvent.fromJson('block_list', json));
    });

    socket.on(SocketEvents.contactsUpdated, (data) {
      final json = data is Map<String, dynamic> ? data : <String, dynamic>{};
      _contactsUpdatedController.add(SyncEvent.fromJson('contacts', json));
    });

    socket.on(SocketEvents.settingsUpdated, (data) {
      final json = data is Map<String, dynamic> ? data : <String, dynamic>{};
      _settingsUpdatedController.add(SyncEvent.fromJson('settings', json));
    });

    socket.on(SocketEvents.privacySettingsUpdated, (data) {
      final json = data is Map<String, dynamic> ? data : <String, dynamic>{};
      _privacySettingsUpdatedController.add(SyncEvent.fromJson('privacy_settings', json));
    });

    socket.on(SocketEvents.mutedConversationsUpdated, (data) {
      final json = data is Map<String, dynamic> ? data : <String, dynamic>{};
      _mutedConversationsUpdatedController.add(SyncEvent.fromJson('muted_conversations', json));
    });

    // Session events
    socket.on(SocketEvents.sessionInvalidated, (data) {
      final json = data is Map<String, dynamic> ? data : <String, dynamic>{};
      _sessionInvalidatedController.add(SessionInvalidatedEvent.fromJson(json));
    });

    socket.on(SocketEvents.sessionDeleted, (data) {
      if (data is Map<String, dynamic>) {
        _sessionDeletedController.add(SessionDeletedEvent.fromJson(data));
      }
    });
  }

  /// Emits a signal event (for typing indicators, etc.).
  void emitSignal(String recipientHandle, Map<String, dynamic> data) {
    _socket?.emit(SocketEvents.signal, {
      'recipient_handle': recipientHandle,
      ...data,
    });
  }

  /// Disposes the socket service.
  void dispose() {
    disconnect();
    // Close message event controllers
    _incomingMessageController.close();
    _outgoingMessageSyncedController.close();
    _incomingMessageSyncedController.close();
    _vaultMessageUpdatedController.close();
    _connectionStateController.close();
    // Close sync event controllers
    _transportKeyRotatedController.close();
    _blockListUpdatedController.close();
    _contactsUpdatedController.close();
    _settingsUpdatedController.close();
    _privacySettingsUpdatedController.close();
    _mutedConversationsUpdatedController.close();
    // Close session event controllers
    _sessionInvalidatedController.close();
    _sessionDeletedController.close();
  }
}
