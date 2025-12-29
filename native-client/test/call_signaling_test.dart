/// Tests for the call signaling flow.
/// These tests verify the signaling message structure and state management.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ratchet_chat/src/realtime/realtime.dart';

void main() {
  group('SocketService Signaling', () {
    group('Signal Types', () {
      test('defines all required signal types', () {
        expect(SignalTypes.typing, equals('typing'));
        expect(SignalTypes.stopTyping, equals('stop-typing'));
        expect(SignalTypes.callOffer, equals('call-offer'));
        expect(SignalTypes.callAnswer, equals('call-answer'));
        expect(SignalTypes.iceCandidate, equals('ice-candidate'));
        expect(SignalTypes.callEnd, equals('call-end'));
      });
    });

    group('SignalMessage', () {
      test('parses signal message from JSON', () {
        final json = {
          'type': 'call-offer',
          'from': 'alice@example.com',
          'data': {
            'sdp': {'type': 'offer', 'sdp': 'v=0...'},
            'isVideo': true,
          },
        };

        final signal = SignalMessage.fromJson(json);

        expect(signal.type, equals('call-offer'));
        expect(signal.fromHandle, equals('alice@example.com'));
        expect(signal.data, isA<Map<String, dynamic>>());
        expect((signal.data as Map<String, dynamic>)['isVideo'], isTrue);
      });

      test('parses typing signal', () {
        final json = {
          'type': 'typing',
          'from': 'bob@example.com',
          'data': null,
        };

        final signal = SignalMessage.fromJson(json);

        expect(signal.type, equals('typing'));
        expect(signal.fromHandle, equals('bob@example.com'));
        expect(signal.data, isNull);
      });

      test('parses ice-candidate signal', () {
        final json = {
          'type': 'ice-candidate',
          'from': 'alice@example.com',
          'data': {
            'candidate': 'candidate:123 1 UDP 2130706431 192.168.1.1 54321 typ host',
            'sdpMid': 'audio',
            'sdpMLineIndex': 0,
          },
        };

        final signal = SignalMessage.fromJson(json);

        expect(signal.type, equals('ice-candidate'));
        expect(signal.fromHandle, equals('alice@example.com'));

        final data = signal.data as Map<String, dynamic>;
        expect(data['candidate'], contains('candidate:123'));
        expect(data['sdpMid'], equals('audio'));
        expect(data['sdpMLineIndex'], equals(0));
      });
    });

    group('SocketState', () {
      test('defines all connection states', () {
        expect(SocketState.values, contains(SocketState.disconnected));
        expect(SocketState.values, contains(SocketState.connecting));
        expect(SocketState.values, contains(SocketState.connected));
        expect(SocketState.values, contains(SocketState.reconnecting));
      });
    });
  });

  group('WebRtcService State', () {
    group('CallState', () {
      test('defines all call states', () {
        expect(CallState.values, contains(CallState.idle));
        expect(CallState.values, contains(CallState.requesting));
        expect(CallState.values, contains(CallState.ringing));
        expect(CallState.values, contains(CallState.connecting));
        expect(CallState.values, contains(CallState.connected));
        expect(CallState.values, contains(CallState.ended));
        expect(CallState.values, contains(CallState.failed));
      });

      test('has correct number of states', () {
        expect(CallState.values.length, equals(7));
      });
    });

    group('CallDirection', () {
      test('defines incoming and outgoing', () {
        expect(CallDirection.values, contains(CallDirection.incoming));
        expect(CallDirection.values, contains(CallDirection.outgoing));
        expect(CallDirection.values.length, equals(2));
      });
    });

    group('CallInfo', () {
      test('creates with required fields', () {
        final info = CallInfo(
          remoteHandle: 'alice@example.com',
          isVideo: true,
          direction: CallDirection.outgoing,
        );

        expect(info.remoteHandle, equals('alice@example.com'));
        expect(info.isVideo, isTrue);
        expect(info.direction, equals(CallDirection.outgoing));
        expect(info.startTime, isA<DateTime>());
      });

      test('can specify start time', () {
        final specificTime = DateTime(2024, 1, 15, 10, 30);
        final info = CallInfo(
          remoteHandle: 'bob@example.com',
          isVideo: false,
          direction: CallDirection.incoming,
          startTime: specificTime,
        );

        expect(info.startTime, equals(specificTime));
      });
    });

    group('IceState', () {
      test('defines all ICE states', () {
        expect(IceState.values, contains(IceState.checking));
        expect(IceState.values, contains(IceState.connected));
        expect(IceState.values, contains(IceState.completed));
        expect(IceState.values, contains(IceState.failed));
        expect(IceState.values, contains(IceState.disconnected));
        expect(IceState.values, contains(IceState.closed));
      });
    });
  });

  group('WebRtcConfig', () {
    test('provides STUN servers', () {
      final servers = WebRtcConfig.iceServers;

      expect(servers, isNotEmpty);
      expect(servers.first['urls'], contains('stun.l.google.com'));
    });

    test('provides peer connection configuration', () {
      final config = WebRtcConfig.configuration;

      expect(config['iceServers'], isNotNull);
      expect(config['sdpSemantics'], equals('unified-plan'));
    });

    test('provides audio constraints', () {
      final constraints = WebRtcConfig.audioConstraints;

      expect(constraints['audio'], isNotNull);
      expect(constraints['video'], isFalse);

      final audio = constraints['audio'] as Map<String, dynamic>;
      expect(audio['echoCancellation'], isTrue);
      expect(audio['noiseSuppression'], isTrue);
    });

    test('provides video constraints', () {
      final constraints = WebRtcConfig.videoConstraints;

      expect(constraints['audio'], isNotNull);
      expect(constraints['video'], isNotNull);

      final video = constraints['video'] as Map<String, dynamic>;
      expect(video['facingMode'], equals('user'));
      expect((video['width'] as Map)['ideal'], equals(1280));
    });
  });

  group('Call Signaling Protocol', () {
    test('call offer message structure', () {
      // Simulates the structure of a call offer
      final offerPayload = {
        'type': SignalTypes.callOffer,
        'to': 'bob@example.com',
        'data': {
          'sdp': {
            'type': 'offer',
            'sdp': 'v=0\r\no=- 12345 2 IN IP4 127.0.0.1\r\n...',
          },
          'isVideo': true,
        },
      };

      expect(offerPayload['type'], equals('call-offer'));
      expect(offerPayload['to'], isNotNull);
      expect((offerPayload['data'] as Map)['sdp'], isNotNull);
      expect((offerPayload['data'] as Map)['isVideo'], isNotNull);
    });

    test('call answer message structure', () {
      final answerPayload = {
        'type': SignalTypes.callAnswer,
        'to': 'alice@example.com',
        'data': {
          'sdp': {
            'type': 'answer',
            'sdp': 'v=0\r\no=- 67890 2 IN IP4 127.0.0.1\r\n...',
          },
        },
      };

      expect(answerPayload['type'], equals('call-answer'));
      expect((answerPayload['data'] as Map)['sdp'], isNotNull);
    });

    test('ice candidate message structure', () {
      final candidatePayload = {
        'type': SignalTypes.iceCandidate,
        'to': 'alice@example.com',
        'data': {
          'candidate': 'candidate:4234997325 1 udp 2043278322 192.168.0.1 44329 typ host',
          'sdpMid': '0',
          'sdpMLineIndex': 0,
        },
      };

      expect(candidatePayload['type'], equals('ice-candidate'));
      expect((candidatePayload['data'] as Map)['candidate'], isA<String>());
      expect((candidatePayload['data'] as Map)['sdpMid'], isNotNull);
      expect((candidatePayload['data'] as Map)['sdpMLineIndex'], isNotNull);
    });

    test('call end message structure', () {
      final endPayload = {
        'type': SignalTypes.callEnd,
        'to': 'bob@example.com',
        'data': null,
      };

      expect(endPayload['type'], equals('call-end'));
    });
  });

  group('Call Flow Simulation', () {
    test('complete call flow: offer -> answer -> connected', () async {
      // Simulates a complete call flow without actual WebRTC

      final callStates = <CallState>[];
      final stateController = StreamController<CallState>.broadcast();

      stateController.stream.listen((state) {
        callStates.add(state);
      });

      // Caller initiates
      stateController.add(CallState.requesting);
      await Future.delayed(Duration.zero);

      // Offer sent, waiting for answer
      stateController.add(CallState.ringing);
      await Future.delayed(Duration.zero);

      // Answer received, ICE connecting
      stateController.add(CallState.connecting);
      await Future.delayed(Duration.zero);

      // ICE connected
      stateController.add(CallState.connected);
      await Future.delayed(Duration.zero);

      expect(callStates, containsAllInOrder([
        CallState.requesting,
        CallState.ringing,
        CallState.connecting,
        CallState.connected,
      ]));

      await stateController.close();
    });

    test('call rejection flow: offer -> end', () async {
      final callStates = <CallState>[];
      final stateController = StreamController<CallState>.broadcast();

      stateController.stream.listen((state) {
        callStates.add(state);
      });

      // Caller initiates
      stateController.add(CallState.requesting);
      await Future.delayed(Duration.zero);

      // Offer sent
      stateController.add(CallState.ringing);
      await Future.delayed(Duration.zero);

      // Remote rejected
      stateController.add(CallState.ended);
      await Future.delayed(Duration.zero);

      expect(callStates, containsAllInOrder([
        CallState.requesting,
        CallState.ringing,
        CallState.ended,
      ]));

      await stateController.close();
    });

    test('call failure flow: connecting -> failed', () async {
      final callStates = <CallState>[];
      final stateController = StreamController<CallState>.broadcast();

      stateController.stream.listen((state) {
        callStates.add(state);
      });

      stateController.add(CallState.connecting);
      await Future.delayed(Duration.zero);

      // ICE failure
      stateController.add(CallState.failed);
      await Future.delayed(Duration.zero);

      expect(callStates, containsAllInOrder([
        CallState.connecting,
        CallState.failed,
      ]));

      await stateController.close();
    });
  });

  group('IncomingMessageNotification', () {
    test('parses from JSON correctly', () {
      final json = {
        'messageId': 'msg-123',
        'senderHandle': 'alice@example.com',
        'timestamp': '2024-01-15T10:30:00.000Z',
      };

      final notification = IncomingMessageNotification.fromJson(json);

      expect(notification.messageId, equals('msg-123'));
      expect(notification.senderHandle, equals('alice@example.com'));
      expect(notification.timestamp.year, equals(2024));
    });
  });
}
