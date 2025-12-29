// Copyright (c) 2021 Cloudflare, Inc. and contributors.
// Ported to Dart for Ratchet-Chat Flutter client.
// Licensed under the BSD-3-Clause license.

import 'dart:convert';
import 'dart:typed_data';

import 'ake_client.dart';
import 'config.dart';
import 'core_client.dart';
import 'crypto.dart';
import 'messages.dart';

/// OPAQUE client states.
enum OpaqueClientState {
  ready,
  registrationStarted,
  loginStarted,
}

/// Result of successful registration.
class RegistrationResult {
  final RegistrationRecord record;
  final List<int> exportKey;

  RegistrationResult({required this.record, required this.exportKey});
}

/// Result of successful login.
class LoginResult {
  final KE3 ke3;
  final List<int> sessionKey;
  final List<int> exportKey;

  LoginResult({
    required this.ke3,
    required this.sessionKey,
    required this.exportKey,
  });
}

/// OPAQUE client for password-authenticated key exchange.
///
/// Usage for registration:
/// ```dart
/// final client = OpaqueClient(getOpaqueConfig(OpaqueId.opaqueP256));
///
/// // Step 1: Start registration
/// final request = client.registerInit(password);
/// // Send request.serialize() to server
///
/// // Step 2: Receive server response and finish
/// final result = client.registerFinish(serverResponse);
/// // Send result.record.serialize() to server
/// ```
///
/// Usage for login:
/// ```dart
/// final client = OpaqueClient(getOpaqueConfig(OpaqueId.opaqueP256));
///
/// // Step 1: Start login
/// final ke1 = client.authInit(password);
/// // Send ke1.serialize() to server
///
/// // Step 2: Receive server response and finish
/// final result = client.authFinish(ke2);
/// // Send result.ke3.serialize() to server
/// // Use result.sessionKey for encryption
/// ```
class OpaqueClient {
  final OpaqueConfig config;
  final OpaqueCoreClient _opaqueCore;
  final Ake3DHClient _ake;

  OpaqueClientState _status = OpaqueClientState.ready;
  Uint8List? _blind;
  Uint8List? _password;
  KE1? _ke1;

  OpaqueClient(this.config, [MemHardFn? memHard])
      : _opaqueCore = OpaqueCoreClient(config, memHard),
        _ake = Ake3DHClient(config);

  /// Start OPAQUE registration.
  ///
  /// Returns the registration request to send to the server.
  RegistrationRequest registerInit(String password) {
    if (_status != OpaqueClientState.ready) {
      throw StateError('Client not ready');
    }

    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    final result = _opaqueCore.createRegistrationRequest(passwordBytes);

    _blind = result.blind;
    _password = passwordBytes;
    _status = OpaqueClientState.registrationStarted;

    return result.request;
  }

  /// Complete OPAQUE registration.
  ///
  /// Returns the registration record to send to the server.
  RegistrationResult registerFinish(
    RegistrationResponse response, {
    String? serverIdentity,
    String? clientIdentity,
  }) {
    if (_status != OpaqueClientState.registrationStarted ||
        _password == null ||
        _blind == null) {
      throw StateError('Client not ready');
    }

    final serverIdentityBytes =
        serverIdentity != null ? Uint8List.fromList(utf8.encode(serverIdentity)) : null;
    final clientIdentityBytes =
        clientIdentity != null ? Uint8List.fromList(utf8.encode(clientIdentity)) : null;

    final result = _opaqueCore.finalizeRequest(
      _password!,
      _blind!,
      response,
      serverIdentityBytes,
      clientIdentityBytes,
    );

    _clean();

    return RegistrationResult(
      record: result.record,
      exportKey: result.exportKey,
    );
  }

  /// Start OPAQUE login.
  ///
  /// Returns KE1 message to send to the server.
  KE1 authInit(String password) {
    if (_status != OpaqueClientState.ready) {
      throw StateError('Client not ready');
    }

    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    final credResult = _opaqueCore.createCredentialRequest(passwordBytes);
    final authInit = _ake.start();

    final ke1 = KE1(
      request: credResult.request,
      authInit: authInit,
    );

    _blind = credResult.blind;
    _password = passwordBytes;
    _ke1 = ke1;
    _status = OpaqueClientState.loginStarted;

    return ke1;
  }

  /// Complete OPAQUE login.
  ///
  /// Returns the KE3 message to send to the server and the session key.
  LoginResult authFinish(
    KE2 ke2, {
    String? serverIdentity,
    String? clientIdentity,
    String? context,
  }) {
    if (_status != OpaqueClientState.loginStarted ||
        _password == null ||
        _blind == null ||
        _ke1 == null) {
      throw StateError('Client not ready');
    }

    final serverIdentityBytes =
        serverIdentity != null ? Uint8List.fromList(utf8.encode(serverIdentity)) : null;
    final clientIdentityBytes =
        clientIdentity != null ? Uint8List.fromList(utf8.encode(clientIdentity)) : null;
    final contextBytes =
        context != null ? Uint8List.fromList(utf8.encode(context)) : Uint8List(0);

    final recovered = _opaqueCore.recoverCredentials(
      _password!,
      _blind!,
      ke2.response,
      serverIdentityBytes,
      clientIdentityBytes,
    );

    if (recovered == null) {
      _clean();
      throw Exception('Failed to recover credentials');
    }

    final finalResult = _ake.finalize(
      clientIdentity: clientIdentityBytes ?? recovered.clientAkeKeyPair.publicKey,
      clientPrivateKey: recovered.clientAkeKeyPair.privateKey,
      serverIdentity: serverIdentityBytes ?? recovered.serverPublicKey,
      serverPublicKey: recovered.serverPublicKey,
      ke1: _ke1!,
      ke2: ke2,
      context: contextBytes,
    );

    final ke3 = KE3(authFinish: finalResult.authFinish);

    _clean();

    return LoginResult(
      ke3: ke3,
      sessionKey: finalResult.sessionKey.toList(),
      exportKey: recovered.exportKey.toList(),
    );
  }

  /// Reset client state.
  void _clean() {
    _status = OpaqueClientState.ready;
    _password = null;
    _blind = null;
    _ke1 = null;
  }
}
