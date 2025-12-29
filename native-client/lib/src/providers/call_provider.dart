// Call provider for managing voice/video calls.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../realtime/realtime.dart';

/// Incoming call notification.
class IncomingCall {
  final String fromHandle;
  final bool isVideo;
  final Map<String, dynamic> sdp;
  final DateTime timestamp;

  IncomingCall({
    required this.fromHandle,
    required this.isVideo,
    required this.sdp,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Call provider that integrates WebRTC with Socket.IO signaling.
class CallProvider extends ChangeNotifier {
  final WebRtcService _webRtcService;
  final SocketService _socketService;

  StreamSubscription? _signalSubscription;
  StreamSubscription? _iceCandidateSubscription;
  StreamSubscription? _stateChangeSubscription;
  StreamSubscription? _remoteStreamSubscription;

  IncomingCall? _incomingCall;
  final List<RTCIceCandidate> _pendingCandidates = [];

  CallProvider({
    required WebRtcService webRtcService,
    required SocketService socketService,
  })  : _webRtcService = webRtcService,
        _socketService = socketService {
    _setupListeners();
  }

  /// Current call state.
  CallState get state => _webRtcService.state;

  /// Current call info.
  CallInfo? get callInfo => _webRtcService.callInfo;

  /// Incoming call waiting for response.
  IncomingCall? get incomingCall => _incomingCall;

  /// Whether there's an incoming call.
  bool get hasIncomingCall => _incomingCall != null;

  /// Whether currently in a call.
  bool get isInCall => _webRtcService.isInCall;

  /// Whether microphone is muted.
  bool get isMuted => _webRtcService.isMuted;

  /// Whether video is enabled.
  bool get isVideoEnabled => _webRtcService.isVideoEnabled;

  /// Whether speaker is on.
  bool get isSpeakerOn => _webRtcService.isSpeakerOn;

  /// Whether using front camera.
  bool get isFrontCamera => _webRtcService.isFrontCamera;

  /// Local media stream.
  MediaStream? get localStream => _webRtcService.localStream;

  /// Remote media stream.
  MediaStream? get remoteStream => _webRtcService.remoteStream;

  /// Remote handle of current or incoming call.
  String? get remoteHandle =>
      _webRtcService.callInfo?.remoteHandle ?? _incomingCall?.fromHandle;

  /// Whether this is a video call.
  bool get isVideoCall =>
      _webRtcService.callInfo?.isVideo ?? _incomingCall?.isVideo ?? false;

  // ============== Call Actions ==============

  /// Initiate a call to a remote user.
  Future<bool> initiateCall({
    required String handle,
    required bool isVideo,
  }) async {
    if (!_socketService.isConnected) {
      debugPrint('Cannot initiate call: socket not connected');
      return false;
    }

    final offer = await _webRtcService.createOffer(
      remoteHandle: handle,
      isVideo: isVideo,
    );

    if (offer == null) {
      debugPrint('Failed to create offer');
      return false;
    }

    // Send offer via socket
    _socketService.sendCallOffer(
      targetHandle: handle,
      sdp: {'type': offer.type, 'sdp': offer.sdp},
      isVideo: isVideo,
    );

    return true;
  }

  /// Accept an incoming call.
  Future<bool> acceptCall() async {
    if (_incomingCall == null) {
      debugPrint('No incoming call to accept');
      return false;
    }

    if (!_socketService.isConnected) {
      debugPrint('Cannot accept call: socket not connected');
      return false;
    }

    final incoming = _incomingCall!;
    _incomingCall = null;

    final offer = RTCSessionDescription(
      incoming.sdp['sdp'] as String,
      incoming.sdp['type'] as String,
    );

    final answer = await _webRtcService.createAnswer(
      remoteHandle: incoming.fromHandle,
      offer: offer,
      isVideo: incoming.isVideo,
    );

    if (answer == null) {
      debugPrint('Failed to create answer');
      return false;
    }

    // Send answer via socket
    _socketService.sendCallAnswer(
      targetHandle: incoming.fromHandle,
      sdp: {'type': answer.type, 'sdp': answer.sdp},
    );

    // Process any pending ICE candidates
    for (final candidate in _pendingCandidates) {
      await _webRtcService.addIceCandidate(candidate);
    }
    _pendingCandidates.clear();

    notifyListeners();
    return true;
  }

  /// Reject an incoming call.
  void rejectCall() {
    if (_incomingCall == null) return;

    final handle = _incomingCall!.fromHandle;
    _incomingCall = null;
    _pendingCandidates.clear();

    // Send call end signal
    _socketService.sendCallEnd(handle);
    notifyListeners();
  }

  /// End the current call.
  Future<void> endCall() async {
    final handle =
        _webRtcService.callInfo?.remoteHandle ?? _incomingCall?.fromHandle;

    if (handle != null) {
      _socketService.sendCallEnd(handle);
    }

    _incomingCall = null;
    _pendingCandidates.clear();
    await _webRtcService.endCall();
    notifyListeners();
  }

  /// Toggle microphone mute.
  void toggleMute() {
    _webRtcService.toggleMute();
  }

  /// Toggle local video.
  void toggleVideo() {
    _webRtcService.toggleVideo();
  }

  /// Toggle speaker.
  Future<void> toggleSpeaker() async {
    await _webRtcService.toggleSpeaker();
  }

  /// Switch camera.
  Future<void> switchCamera() async {
    await _webRtcService.switchCamera();
  }

  // ============== Private Methods ==============

  void _setupListeners() {
    // Listen for signaling messages
    _signalSubscription = _socketService.onSignal.listen(_handleSignal);

    // Forward ICE candidates to remote peer
    _iceCandidateSubscription =
        _webRtcService.onIceCandidate.listen((candidate) {
      final handle = _webRtcService.callInfo?.remoteHandle;
      if (handle != null) {
        _socketService.sendIceCandidate(
          targetHandle: handle,
          candidate: candidate.toMap(),
        );
      }
    });

    // Listen for state changes
    _stateChangeSubscription = _webRtcService.onStateChange.listen((state) {
      notifyListeners();
    });

    // Listen for remote stream
    _remoteStreamSubscription = _webRtcService.onRemoteStream.listen((stream) {
      notifyListeners();
    });
  }

  void _handleSignal(SignalMessage signal) {
    switch (signal.type) {
      case SignalTypes.callOffer:
        _handleCallOffer(signal);
        break;
      case SignalTypes.callAnswer:
        _handleCallAnswer(signal);
        break;
      case SignalTypes.iceCandidate:
        _handleIceCandidate(signal);
        break;
      case SignalTypes.callEnd:
        _handleCallEnd(signal);
        break;
    }
  }

  void _handleCallOffer(SignalMessage signal) {
    // Ignore if already in a call
    if (isInCall || hasIncomingCall) {
      debugPrint('Ignoring call offer: already in call or has incoming');
      // Send busy signal
      _socketService.sendCallEnd(signal.fromHandle);
      return;
    }

    final data = signal.data as Map<String, dynamic>;
    final sdp = data['sdp'] as Map<String, dynamic>;
    final isVideo = data['isVideo'] as bool? ?? false;

    _incomingCall = IncomingCall(
      fromHandle: signal.fromHandle,
      isVideo: isVideo,
      sdp: sdp,
    );

    notifyListeners();
  }

  void _handleCallAnswer(SignalMessage signal) {
    final data = signal.data as Map<String, dynamic>;
    final sdp = data['sdp'] as Map<String, dynamic>;

    final answer = RTCSessionDescription(
      sdp['sdp'] as String,
      sdp['type'] as String,
    );

    _webRtcService.handleAnswer(answer);
  }

  void _handleIceCandidate(SignalMessage signal) {
    final data = signal.data as Map<String, dynamic>;

    final candidate = RTCIceCandidate(
      data['candidate'] as String?,
      data['sdpMid'] as String?,
      data['sdpMLineIndex'] as int?,
    );

    // If we're still setting up, queue the candidate
    if (_webRtcService.state == CallState.ringing ||
        _webRtcService.state == CallState.requesting) {
      _pendingCandidates.add(candidate);
    } else {
      _webRtcService.addIceCandidate(candidate);
    }
  }

  void _handleCallEnd(SignalMessage signal) {
    // Only end if it's from the person we're in a call with
    final currentHandle =
        _webRtcService.callInfo?.remoteHandle ?? _incomingCall?.fromHandle;

    if (currentHandle == signal.fromHandle) {
      _incomingCall = null;
      _pendingCandidates.clear();
      _webRtcService.endCall();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _signalSubscription?.cancel();
    _iceCandidateSubscription?.cancel();
    _stateChangeSubscription?.cancel();
    _remoteStreamSubscription?.cancel();
    super.dispose();
  }
}
