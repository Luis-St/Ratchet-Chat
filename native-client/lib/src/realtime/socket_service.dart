// Socket.IO service for real-time communication.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Socket event types.
class SocketEvents {
  static const String connect = 'connect';
  static const String disconnect = 'disconnect';
  static const String connectError = 'connect_error';
  static const String incomingMessage = 'INCOMING_MESSAGE';
  static const String signal = 'signal';
}

/// Signal types for ephemeral events.
class SignalTypes {
  static const String typing = 'typing';
  static const String stopTyping = 'stop-typing';
  static const String callOffer = 'call-offer';
  static const String callAnswer = 'call-answer';
  static const String iceCandidate = 'ice-candidate';
  static const String callEnd = 'call-end';
}

/// Socket connection state.
enum SocketState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Incoming message notification.
class IncomingMessageNotification {
  final String messageId;
  final String senderHandle;
  final DateTime timestamp;

  IncomingMessageNotification({
    required this.messageId,
    required this.senderHandle,
    required this.timestamp,
  });

  factory IncomingMessageNotification.fromJson(Map<String, dynamic> json) {
    return IncomingMessageNotification(
      messageId: json['messageId'] as String,
      senderHandle: json['senderHandle'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Signal message.
class SignalMessage {
  final String type;
  final String fromHandle;
  final dynamic data;

  SignalMessage({
    required this.type,
    required this.fromHandle,
    required this.data,
  });

  factory SignalMessage.fromJson(Map<String, dynamic> json) {
    return SignalMessage(
      type: json['type'] as String,
      fromHandle: json['from'] as String,
      data: json['data'],
    );
  }
}

/// Socket.IO service for real-time messaging.
class SocketService extends ChangeNotifier {
  io.Socket? _socket;
  String? _serverUrl;
  String? _authToken;
  SocketState _state = SocketState.disconnected;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  // Event streams
  final _incomingMessageController = StreamController<IncomingMessageNotification>.broadcast();
  final _signalController = StreamController<SignalMessage>.broadcast();
  final _connectionStateController = StreamController<SocketState>.broadcast();

  /// Current connection state.
  SocketState get state => _state;

  /// Whether the socket is connected.
  bool get isConnected => _state == SocketState.connected;

  /// Stream of incoming message notifications.
  Stream<IncomingMessageNotification> get onIncomingMessage => _incomingMessageController.stream;

  /// Stream of signal messages (typing, calls, etc.).
  Stream<SignalMessage> get onSignal => _signalController.stream;

  /// Stream of connection state changes.
  Stream<SocketState> get onConnectionStateChange => _connectionStateController.stream;

  /// Connect to the server.
  void connect({
    required String serverUrl,
    required String authToken,
  }) {
    if (_state == SocketState.connected || _state == SocketState.connecting) {
      return;
    }

    _serverUrl = serverUrl;
    _authToken = authToken;
    _setState(SocketState.connecting);

    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': authToken})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(_maxReconnectAttempts)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    _setupEventHandlers();
    _socket!.connect();
  }

  /// Setup socket event handlers.
  void _setupEventHandlers() {
    _socket!.on(SocketEvents.connect, (_) {
      debugPrint('Socket connected');
      _reconnectAttempts = 0;
      _setState(SocketState.connected);
    });

    _socket!.on(SocketEvents.disconnect, (reason) {
      debugPrint('Socket disconnected: $reason');
      _setState(SocketState.disconnected);
    });

    _socket!.on(SocketEvents.connectError, (error) {
      debugPrint('Socket connection error: $error');
      _reconnectAttempts++;

      if (_reconnectAttempts >= _maxReconnectAttempts) {
        _setState(SocketState.disconnected);
      } else {
        _setState(SocketState.reconnecting);
      }
    });

    _socket!.on('reconnect_attempt', (attempt) {
      debugPrint('Socket reconnecting: attempt $attempt');
      _setState(SocketState.reconnecting);
    });

    _socket!.on(SocketEvents.incomingMessage, (data) {
      try {
        final notification = IncomingMessageNotification.fromJson(
          data as Map<String, dynamic>,
        );
        _incomingMessageController.add(notification);
      } catch (e) {
        debugPrint('Failed to parse incoming message: $e');
      }
    });

    _socket!.on(SocketEvents.signal, (data) {
      try {
        final signal = SignalMessage.fromJson(data as Map<String, dynamic>);
        _signalController.add(signal);
      } catch (e) {
        debugPrint('Failed to parse signal: $e');
      }
    });
  }

  /// Disconnect from the server.
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _setState(SocketState.disconnected);
  }

  /// Emit an event to the server.
  void emit(String event, dynamic data) {
    if (_socket == null || !isConnected) {
      debugPrint('Cannot emit: socket not connected');
      return;
    }
    _socket!.emit(event, data);
  }

  /// Send a signal to another user.
  void sendSignal({
    required String type,
    required String targetHandle,
    dynamic data,
  }) {
    emit(SocketEvents.signal, {
      'type': type,
      'to': targetHandle,
      'data': data,
    });
  }

  /// Send typing indicator.
  void sendTyping(String targetHandle) {
    sendSignal(
      type: SignalTypes.typing,
      targetHandle: targetHandle,
    );
  }

  /// Send stop typing indicator.
  void sendStopTyping(String targetHandle) {
    sendSignal(
      type: SignalTypes.stopTyping,
      targetHandle: targetHandle,
    );
  }

  /// Send call offer.
  void sendCallOffer({
    required String targetHandle,
    required Map<String, dynamic> sdp,
    required bool isVideo,
  }) {
    sendSignal(
      type: SignalTypes.callOffer,
      targetHandle: targetHandle,
      data: {
        'sdp': sdp,
        'isVideo': isVideo,
      },
    );
  }

  /// Send call answer.
  void sendCallAnswer({
    required String targetHandle,
    required Map<String, dynamic> sdp,
  }) {
    sendSignal(
      type: SignalTypes.callAnswer,
      targetHandle: targetHandle,
      data: {'sdp': sdp},
    );
  }

  /// Send ICE candidate.
  void sendIceCandidate({
    required String targetHandle,
    required Map<String, dynamic> candidate,
  }) {
    sendSignal(
      type: SignalTypes.iceCandidate,
      targetHandle: targetHandle,
      data: candidate,
    );
  }

  /// Send call end.
  void sendCallEnd(String targetHandle) {
    sendSignal(
      type: SignalTypes.callEnd,
      targetHandle: targetHandle,
    );
  }

  /// Update connection state.
  void _setState(SocketState newState) {
    if (_state != newState) {
      _state = newState;
      _connectionStateController.add(newState);
      notifyListeners();
    }
  }

  /// Reconnect with new token (e.g., after token refresh).
  void reconnectWithToken(String newToken) {
    _authToken = newToken;
    if (_serverUrl != null) {
      disconnect();
      connect(serverUrl: _serverUrl!, authToken: newToken);
    }
  }

  @override
  void dispose() {
    disconnect();
    _incomingMessageController.close();
    _signalController.close();
    _connectionStateController.close();
    super.dispose();
  }
}
