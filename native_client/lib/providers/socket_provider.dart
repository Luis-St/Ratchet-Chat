import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/socket_service.dart';
import 'auth_provider.dart';
import 'server_provider.dart';
import 'service_providers.dart';

/// State for the socket connection.
class SocketState {
  final bool isConnected;
  final bool isConnecting;
  final String? error;

  const SocketState({
    this.isConnected = false,
    this.isConnecting = false,
    this.error,
  });

  SocketState copyWith({
    bool? isConnected,
    bool? isConnecting,
    String? error,
  }) {
    return SocketState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      error: error,
    );
  }
}

/// Notifier for managing the socket connection.
class SocketNotifier extends Notifier<SocketState> {
  late SocketService _socketService;
  StreamSubscription<bool>? _connectionSubscription;

  @override
  SocketState build() {
    _socketService = ref.watch(socketServiceProvider);

    // Listen to connection state changes
    _connectionSubscription?.cancel();
    _connectionSubscription = _socketService.onConnectionStateChange.listen(
      (isConnected) {
        state = state.copyWith(
          isConnected: isConnected,
          isConnecting: false,
        );
      },
    );

    // Auto-connect when authenticated
    final authState = ref.watch(authProvider);
    final serverState = ref.watch(serverProvider);

    if (authState.isAuthenticated && serverState.activeServer?.url != null) {
      final session = ref.read(authProvider.notifier).session;
      if (session != null) {
        // Defer connection until after build() completes to avoid accessing state
        Future.microtask(() {
          _connect(serverState.activeServer!.url, session.token);
        });
      }
    } else {
      // Disconnect when logged out
      _socketService.disconnect();
    }

    ref.onDispose(() {
      _connectionSubscription?.cancel();
    });

    return SocketState(isConnected: _socketService.isConnected);
  }

  void _connect(String serverUrl, String token) {
    if (_socketService.isConnected) return;

    state = state.copyWith(isConnecting: true);
    _socketService.connect(serverUrl, token);
  }

  /// Manually reconnect.
  void reconnect() {
    final authState = ref.read(authProvider);
    final serverState = ref.read(serverProvider);

    if (authState.isAuthenticated && serverState.activeServer?.url != null) {
      final session = ref.read(authProvider.notifier).session;
      if (session != null) {
        _socketService.disconnect();
        _connect(serverState.activeServer!.url, session.token);
      }
    }
  }

  /// Disconnect.
  void disconnect() {
    _socketService.disconnect();
    state = const SocketState();
  }

  /// Get the socket service for subscribing to events.
  SocketService get socketService => _socketService;
}

/// Provider for socket connection state.
final socketProvider = NotifierProvider<SocketNotifier, SocketState>(
  SocketNotifier.new,
);

/// Provider for incoming message events stream.
final incomingMessageEventsProvider = StreamProvider<IncomingMessageEvent>((ref) {
  final socketService = ref.watch(socketServiceProvider);
  return socketService.onIncomingMessage;
});

/// Provider for vault update events stream.
final vaultUpdateEventsProvider = StreamProvider<VaultUpdateEvent>((ref) {
  final socketService = ref.watch(socketServiceProvider);
  return socketService.onVaultMessageUpdated;
});
