/// Integration tests for OPAQUE client-server flow.
///
/// These tests simulate the server-side operations to verify the full
/// OPAQUE protocol works correctly end-to-end.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ratchet_chat/src/opaque/opaque.dart';
import 'package:ratchet_chat/src/opaque/crypto.dart';
import 'package:ratchet_chat/src/opaque/util.dart';
import 'package:ratchet_chat/src/opaque/oprf.dart';
import 'package:ratchet_chat/src/opaque/common.dart';

/// Simulated OPAQUE server for testing.
/// This implements the server-side OPAQUE operations.
class SimulatedOpaqueServer {
  final OpaqueConfig config;
  final Prng _prng;

  // Server's OPRF key
  late final BigInt _oprfKey;
  late final Uint8List _serverPrivateKey;
  late final Uint8List _serverPublicKey;

  // Stored registration records (username -> record)
  final Map<String, RegistrationRecord> _records = {};

  // Pending login states
  final Map<String, _LoginState> _loginStates = {};

  SimulatedOpaqueServer(this.config) : _prng = Prng() {
    // Generate server's OPRF key
    _oprfKey = P256Oprf.randomScalar();

    // Generate server's AKE key pair
    final keyPair = config.ake.generateAuthKeyPair();
    _serverPrivateKey = keyPair.privateKey;
    _serverPublicKey = keyPair.publicKey;
  }

  /// Process registration request and return response.
  RegistrationResponse processRegistrationRequest(
    String username,
    RegistrationRequest request,
  ) {
    // Evaluate OPRF: Z = k * M
    final blindedPoint = P256Oprf.deserializePoint(request.data);
    final evaluated = P256Oprf.scalarMult(blindedPoint, _oprfKey);
    final evaluation = P256Oprf.serializePoint(evaluated);

    return RegistrationResponse(
      evaluation: evaluation,
      serverPublicKey: _serverPublicKey,
    );
  }

  /// Store registration record.
  void storeRegistrationRecord(String username, RegistrationRecord record) {
    _records[username] = record;
  }

  /// Process login request (KE1) and return KE2.
  KE2 processLoginRequest(String username, KE1 ke1) {
    final record = _records[username];
    if (record == null) {
      throw Exception('User not found');
    }

    // Evaluate OPRF
    final blindedPoint = P256Oprf.deserializePoint(ke1.request.data);
    final evaluated = P256Oprf.scalarMult(blindedPoint, _oprfKey);
    final evaluation = P256Oprf.serializePoint(evaluated);

    // Generate masking nonce and mask the response
    final maskingNonce = Uint8List.fromList(_prng.random(config.constants.Nn));

    // Create credential response pad
    final credentialResponsePad = config.kdf.expand(
      record.maskingKey,
      joinAll([maskingNonce, Labels.credentialResponsePad]),
      config.ake.Npk + Envelope.sizeSerialized(config),
    );

    // Mask server public key and envelope
    final serverPubKeyEnvelope = joinAll([
      _serverPublicKey,
      Uint8List.fromList(record.envelope.serialize()),
    ]);
    final maskedResponse = xor(credentialResponsePad, serverPubKeyEnvelope);

    final credentialResponse = CredentialResponse(
      evaluation: evaluation,
      maskingNonce: maskingNonce,
      maskedResponse: maskedResponse,
    );

    // Generate server's ephemeral key pair for this session
    final serverKeyPair = config.ake.generateAuthKeyPair();
    final serverNonce = Uint8List.fromList(_prng.random(config.constants.Nn));

    // Compute Triple-DH IKM
    final ikm = tripleDhIkm(config, [
      (sk: serverKeyPair.privateKey, pk: ke1.authInit.clientKeyshare),
      (sk: _serverPrivateKey, pk: ke1.authInit.clientKeyshare),
      (sk: serverKeyPair.privateKey, pk: record.clientPublicKey),
    ]);

    // Build preamble for key derivation
    final preamble = _buildServerPreamble(
      ke1,
      credentialResponse,
      serverNonce,
      serverKeyPair.publicKey,
      _serverPublicKey,
      record.clientPublicKey,
    );

    // Derive keys
    final keys = deriveKeys(config, ikm, preamble);

    // Compute server MAC
    final hPreamble = config.hash.sum(preamble);
    final serverMac = config.mac.withKey(keys.km2).sign(hPreamble);

    final authResponse = AuthResponse(
      serverNonce: serverNonce,
      serverKeyshare: serverKeyPair.publicKey,
      serverMac: serverMac,
    );

    // Store state for login finish
    _loginStates[username] = _LoginState(
      expectedClientMac: _computeExpectedClientMac(
        config,
        keys.km3,
        preamble,
        serverMac,
      ),
      sessionKey: keys.sessionKey,
    );

    return KE2(response: credentialResponse, authResponse: authResponse);
  }

  /// Process login finish (KE3) and return session key.
  Uint8List processLoginFinish(String username, KE3 ke3) {
    final state = _loginStates.remove(username);
    if (state == null) {
      throw Exception('No pending login state');
    }

    // Verify client MAC
    if (!ctEqual(ke3.authFinish.clientMac, state.expectedClientMac)) {
      throw Exception('Invalid client MAC');
    }

    return state.sessionKey;
  }

  Uint8List _buildServerPreamble(
    KE1 ke1,
    CredentialResponse credentialResponse,
    Uint8List serverNonce,
    Uint8List serverKeyshare,
    Uint8List serverIdentity,
    Uint8List clientIdentity,
  ) {
    return joinAll([
      Labels.rfc,
      encodeVector16(Uint8List(0)), // context
      encodeVector16(clientIdentity),
      Uint8List.fromList(ke1.serialize()),
      encodeVector16(serverIdentity),
      Uint8List.fromList(credentialResponse.serialize()),
      serverNonce,
      serverKeyshare,
    ]);
  }

  Uint8List _computeExpectedClientMac(
    OpaqueConfig config,
    Uint8List km3,
    Uint8List preamble,
    Uint8List serverMac,
  ) {
    final hmacData = config.hash.sum(joinAll([preamble, serverMac]));
    return config.mac.withKey(km3).sign(hmacData);
  }
}

class _LoginState {
  final Uint8List expectedClientMac;
  final Uint8List sessionKey;

  _LoginState({required this.expectedClientMac, required this.sessionKey});
}

void main() {
  group('OPAQUE Integration Tests', () {
    late OpaqueConfig config;
    late SimulatedOpaqueServer server;

    setUp(() {
      config = getOpaqueConfig(OpaqueId.opaqueP256);
      server = SimulatedOpaqueServer(config);
    });

    test('Full registration flow works', () {
      final username = 'testuser';
      final password = 'testpassword123';

      // Client starts registration
      final client = OpaqueClient(config);
      final registrationRequest = client.registerInit(password);

      // Server processes request
      final registrationResponse = server.processRegistrationRequest(
        username,
        registrationRequest,
      );

      // Client finishes registration
      final registrationResult = client.registerFinish(registrationResponse);

      // Server stores the record
      server.storeRegistrationRecord(username, registrationResult.record);

      // Verify export key was generated
      expect(registrationResult.exportKey.length, equals(32));

      // Verify record was stored correctly
      expect(registrationResult.record.clientPublicKey.length, equals(config.ake.Npk));
      expect(registrationResult.record.maskingKey.length, equals(config.hash.Nh));
    });

    test('Full login flow works after registration', () {
      final username = 'loginuser';
      final password = 'securepassword456';

      // First, register the user
      final regClient = OpaqueClient(config);
      final regRequest = regClient.registerInit(password);
      final regResponse = server.processRegistrationRequest(username, regRequest);
      final regResult = regClient.registerFinish(regResponse);
      server.storeRegistrationRecord(username, regResult.record);

      // Now, login
      final loginClient = OpaqueClient(config);
      final ke1 = loginClient.authInit(password);

      // Serialize and deserialize to simulate network transmission
      final ke1Bytes = ke1.serialize();
      final ke1Received = KE1.deserialize(config, ke1Bytes);
      expect(ke1Received.request.data, equals(ke1.request.data));

      // Server processes KE1
      final ke2 = server.processLoginRequest(username, ke1Received);

      // Serialize and deserialize KE2
      final ke2Bytes = ke2.serialize();
      final ke2Received = KE2.deserialize(config, ke2Bytes);

      // Client finishes login
      final loginResult = loginClient.authFinish(ke2Received);

      // Serialize and deserialize KE3
      final ke3Bytes = loginResult.ke3.serialize();
      final ke3Received = KE3.deserialize(config, ke3Bytes);

      // Server verifies KE3 and gets session key
      final serverSessionKey = server.processLoginFinish(username, ke3Received);

      // Both client and server should have the same session key
      expect(
        Uint8List.fromList(loginResult.sessionKey),
        equals(serverSessionKey),
      );
      expect(loginResult.sessionKey.length, equals(32));
      expect(loginResult.exportKey.length, equals(32));
    });

    test('Login fails with wrong password', () {
      final username = 'wrongpwuser';
      final correctPassword = 'correctpassword';
      final wrongPassword = 'wrongpassword';

      // Register with correct password
      final regClient = OpaqueClient(config);
      final regRequest = regClient.registerInit(correctPassword);
      final regResponse = server.processRegistrationRequest(username, regRequest);
      final regResult = regClient.registerFinish(regResponse);
      server.storeRegistrationRecord(username, regResult.record);

      // Try to login with wrong password
      final loginClient = OpaqueClient(config);
      final ke1 = loginClient.authInit(wrongPassword);
      final ke2 = server.processLoginRequest(username, ke1);

      // Client should fail to finish login (envelope MAC verification)
      expect(
        () => loginClient.authFinish(ke2),
        throwsException,
      );
    });

    test('Message sizes match expected protocol sizes', () {
      // Verify message sizes match OPAQUE specification for P-256
      expect(RegistrationRequest.sizeSerialized(config), equals(33)); // Noe
      expect(
        RegistrationResponse.sizeSerialized(config),
        equals(33 + 33), // Noe + Npk
      );
      expect(
        Envelope.sizeSerialized(config),
        equals(32 + 32), // Nn + Nm
      );
      expect(
        RegistrationRecord.sizeSerialized(config),
        equals(33 + 32 + 64), // Npk + Nh + envelope
      );
      expect(
        AuthInit.sizeSerialized(config),
        equals(32 + 33), // Nn + Npk
      );
      expect(
        AuthResponse.sizeSerialized(config),
        equals(32 + 33 + 32), // Nn + Npk + Nm
      );
      expect(AuthFinish.sizeSerialized(config), equals(32)); // Nm
      expect(
        KE1.sizeSerialized(config),
        equals(33 + 32 + 33), // CredentialRequest + AuthInit
      );
      expect(KE3.sizeSerialized(config), equals(32)); // AuthFinish
    });

    test('Multiple users can register and login independently', () {
      final users = [
        ('alice', 'alicepassword'),
        ('bob', 'bobpassword'),
        ('charlie', 'charliepassword'),
      ];

      // Register all users
      for (final (username, password) in users) {
        final client = OpaqueClient(config);
        final request = client.registerInit(password);
        final response = server.processRegistrationRequest(username, request);
        final result = client.registerFinish(response);
        server.storeRegistrationRecord(username, result.record);
      }

      // Login all users and verify they get unique session keys
      final sessionKeys = <Uint8List>[];
      for (final (username, password) in users) {
        final client = OpaqueClient(config);
        final ke1 = client.authInit(password);
        final ke2 = server.processLoginRequest(username, ke1);
        final result = client.authFinish(ke2);
        final serverKey = server.processLoginFinish(username, result.ke3);

        expect(Uint8List.fromList(result.sessionKey), equals(serverKey));
        sessionKeys.add(serverKey);
      }

      // Verify all session keys are unique (different random values)
      expect(sessionKeys[0], isNot(equals(sessionKeys[1])));
      expect(sessionKeys[1], isNot(equals(sessionKeys[2])));
      expect(sessionKeys[0], isNot(equals(sessionKeys[2])));
    });
  });
}
