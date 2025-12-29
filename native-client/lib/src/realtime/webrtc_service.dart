// WebRTC service for voice and video calling.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

/// WebRTC configuration.
class WebRtcConfig {
  /// STUN servers for NAT traversal.
  static const List<Map<String, dynamic>> iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
  ];

  /// Peer connection configuration.
  static Map<String, dynamic> get configuration => {
        'iceServers': iceServers,
        'sdpSemantics': 'unified-plan',
      };

  /// Media constraints for audio calls.
  static Map<String, dynamic> get audioConstraints => {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      };

  /// Media constraints for video calls.
  static Map<String, dynamic> get videoConstraints => {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
      };
}

/// Call state.
enum CallState {
  idle,
  requesting,
  ringing,
  connecting,
  connected,
  ended,
  failed,
}

/// Call direction.
enum CallDirection {
  incoming,
  outgoing,
}

/// ICE connection state wrapper.
enum IceState {
  checking,
  connected,
  completed,
  failed,
  disconnected,
  closed,
}

/// Call info.
class CallInfo {
  final String remoteHandle;
  final bool isVideo;
  final CallDirection direction;
  final DateTime startTime;

  CallInfo({
    required this.remoteHandle,
    required this.isVideo,
    required this.direction,
    DateTime? startTime,
  }) : startTime = startTime ?? DateTime.now();
}

/// WebRTC service for managing peer connections and media streams.
class WebRtcService extends ChangeNotifier {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  CallState _state = CallState.idle;
  CallInfo? _callInfo;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isSpeakerOn = true;
  bool _isFrontCamera = true;

  // Event streams
  final _iceCandidateController = StreamController<RTCIceCandidate>.broadcast();
  final _stateChangeController = StreamController<CallState>.broadcast();
  final _remoteStreamController = StreamController<MediaStream>.broadcast();

  /// Current call state.
  CallState get state => _state;

  /// Current call info.
  CallInfo? get callInfo => _callInfo;

  /// Whether the microphone is muted.
  bool get isMuted => _isMuted;

  /// Whether local video is enabled.
  bool get isVideoEnabled => _isVideoEnabled;

  /// Whether speaker is on.
  bool get isSpeakerOn => _isSpeakerOn;

  /// Whether using front camera.
  bool get isFrontCamera => _isFrontCamera;

  /// Local media stream.
  MediaStream? get localStream => _localStream;

  /// Remote media stream.
  MediaStream? get remoteStream => _remoteStream;

  /// Whether currently in a call.
  bool get isInCall =>
      _state == CallState.connecting || _state == CallState.connected;

  /// Stream of ICE candidates to send to remote peer.
  Stream<RTCIceCandidate> get onIceCandidate => _iceCandidateController.stream;

  /// Stream of call state changes.
  Stream<CallState> get onStateChange => _stateChangeController.stream;

  /// Stream of remote stream additions.
  Stream<MediaStream> get onRemoteStream => _remoteStreamController.stream;

  // ============== Permissions ==============

  /// Request microphone permission.
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Request camera permission.
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request all required permissions for a call.
  Future<bool> requestCallPermissions({required bool isVideo}) async {
    final micGranted = await requestMicrophonePermission();
    if (!micGranted) return false;

    if (isVideo) {
      final cameraGranted = await requestCameraPermission();
      if (!cameraGranted) return false;
    }

    return true;
  }

  // ============== Call Initiation ==============

  /// Create an offer to initiate a call.
  Future<RTCSessionDescription?> createOffer({
    required String remoteHandle,
    required bool isVideo,
  }) async {
    try {
      // Request permissions
      final hasPermissions = await requestCallPermissions(isVideo: isVideo);
      if (!hasPermissions) {
        debugPrint('Permissions not granted for call');
        _setState(CallState.failed);
        return null;
      }

      _setState(CallState.requesting);
      _callInfo = CallInfo(
        remoteHandle: remoteHandle,
        isVideo: isVideo,
        direction: CallDirection.outgoing,
      );

      // Get local media stream
      await _getLocalStream(isVideo: isVideo);

      // Create peer connection
      await _createPeerConnection();

      // Add local tracks to peer connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Create offer
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': isVideo,
      });

      await _peerConnection!.setLocalDescription(offer);

      _setState(CallState.ringing);
      return offer;
    } catch (e) {
      debugPrint('Error creating offer: $e');
      _setState(CallState.failed);
      return null;
    }
  }

  /// Create an answer to respond to an incoming call.
  Future<RTCSessionDescription?> createAnswer({
    required String remoteHandle,
    required RTCSessionDescription offer,
    required bool isVideo,
  }) async {
    try {
      // Request permissions
      final hasPermissions = await requestCallPermissions(isVideo: isVideo);
      if (!hasPermissions) {
        debugPrint('Permissions not granted for call');
        _setState(CallState.failed);
        return null;
      }

      _setState(CallState.connecting);
      _callInfo = CallInfo(
        remoteHandle: remoteHandle,
        isVideo: isVideo,
        direction: CallDirection.incoming,
      );

      // Get local media stream
      await _getLocalStream(isVideo: isVideo);

      // Create peer connection
      await _createPeerConnection();

      // Add local tracks to peer connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Set remote description (the offer)
      await _peerConnection!.setRemoteDescription(offer);

      // Create answer
      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': isVideo,
      });

      await _peerConnection!.setLocalDescription(answer);

      return answer;
    } catch (e) {
      debugPrint('Error creating answer: $e');
      _setState(CallState.failed);
      return null;
    }
  }

  /// Handle incoming answer from remote peer.
  Future<void> handleAnswer(RTCSessionDescription answer) async {
    try {
      if (_peerConnection == null) {
        debugPrint('No peer connection to handle answer');
        return;
      }

      await _peerConnection!.setRemoteDescription(answer);
      _setState(CallState.connecting);
    } catch (e) {
      debugPrint('Error handling answer: $e');
      _setState(CallState.failed);
    }
  }

  /// Add ICE candidate from remote peer.
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    try {
      if (_peerConnection == null) {
        debugPrint('No peer connection to add ICE candidate');
        return;
      }

      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      debugPrint('Error adding ICE candidate: $e');
    }
  }

  // ============== Call Control ==============

  /// End the current call.
  Future<void> endCall() async {
    await _cleanup();
    _setState(CallState.ended);

    // Reset to idle after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_state == CallState.ended) {
        _setState(CallState.idle);
        _callInfo = null;
      }
    });
  }

  /// Toggle microphone mute.
  void toggleMute() {
    if (_localStream == null) return;

    _isMuted = !_isMuted;
    _localStream!.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
    notifyListeners();
  }

  /// Toggle local video.
  void toggleVideo() {
    if (_localStream == null) return;

    _isVideoEnabled = !_isVideoEnabled;
    _localStream!.getVideoTracks().forEach((track) {
      track.enabled = _isVideoEnabled;
    });
    notifyListeners();
  }

  /// Toggle speaker.
  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;

    if (_localStream != null) {
      await Helper.setSpeakerphoneOn(_isSpeakerOn);
    }
    notifyListeners();
  }

  /// Switch between front and back camera.
  Future<void> switchCamera() async {
    if (_localStream == null) return;

    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return;

    await Helper.switchCamera(videoTracks.first);
    _isFrontCamera = !_isFrontCamera;
    notifyListeners();
  }

  // ============== Private Methods ==============

  /// Get local media stream.
  Future<void> _getLocalStream({required bool isVideo}) async {
    final constraints =
        isVideo ? WebRtcConfig.videoConstraints : WebRtcConfig.audioConstraints;

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    _isVideoEnabled = isVideo;
  }

  /// Create peer connection with event handlers.
  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(WebRtcConfig.configuration);

    // Handle ICE candidates
    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _iceCandidateController.add(candidate);
      }
    };

    // Handle ICE connection state changes
    _peerConnection!.onIceConnectionState = (state) {
      debugPrint('ICE connection state: $state');

      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          _setState(CallState.connected);
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _setState(CallState.failed);
          endCall();
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          // May reconnect, don't end call immediately
          debugPrint('ICE disconnected, waiting for reconnection...');
          break;
        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          _setState(CallState.ended);
          break;
        default:
          break;
      }
    };

    // Handle remote track (stream)
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        _remoteStreamController.add(_remoteStream!);
        notifyListeners();
      }
    };

    // Handle connection state changes
    _peerConnection!.onConnectionState = (state) {
      debugPrint('Connection state: $state');
    };
  }

  /// Clean up resources.
  Future<void> _cleanup() async {
    // Stop local tracks
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    await _localStream?.dispose();
    _localStream = null;

    // Close peer connection
    await _peerConnection?.close();
    _peerConnection = null;

    // Clear remote stream
    _remoteStream = null;

    // Reset state
    _isMuted = false;
    _isVideoEnabled = true;
    _isSpeakerOn = true;
    _isFrontCamera = true;
  }

  /// Update call state.
  void _setState(CallState newState) {
    if (_state != newState) {
      _state = newState;
      _stateChangeController.add(newState);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cleanup();
    _iceCandidateController.close();
    _stateChangeController.close();
    _remoteStreamController.close();
    super.dispose();
  }
}
