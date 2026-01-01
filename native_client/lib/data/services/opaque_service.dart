import 'dart:typed_data';

import 'package:opaque_client_dart/opaque_client_dart.dart';

/// Result from starting a registration.
class RegistrationStartResult {
  RegistrationStartResult({required this.request, required this.client});

  final Uint8List request;
  final OpaqueClient client;
}

/// Result from starting a login.
class LoginStartResult {
  LoginStartResult({required this.request, required this.client});

  final Uint8List request;
  final OpaqueClient client;
}

/// Result from finishing a login.
class LoginFinishResult {
  LoginFinishResult({
    required this.finishRequest,
    required this.sessionKey,
    required this.exportKey,
  });

  final Uint8List finishRequest;
  final Uint8List sessionKey;
  final Uint8List exportKey;
}

/// Service wrapping the OPAQUE protocol operations.
class OpaqueService {
  OpaqueService() : _config = getOpaqueConfig(OpaqueId.opaqueP256);

  final OpaqueConfig _config;

  /// Starts the registration process.
  ///
  /// Returns the registration request to send to the server
  /// and the client state needed to finish registration.
  RegistrationStartResult registerStart(String password) {
    final client = OpaqueClient(_config);
    final request = client.registerInit(password);
    return RegistrationStartResult(
      request: Uint8List.fromList(request.serialize()),
      client: client,
    );
  }

  /// Finishes the registration process.
  ///
  /// Takes the server response and returns the registration record
  /// that should be sent to the server for storage.
  Uint8List registerFinish(OpaqueClient client, Uint8List serverResponse) {
    final response = RegistrationResponse.deserialize(
      _config,
      serverResponse.toList(),
    );
    final result = client.registerFinish(response);
    return Uint8List.fromList(result.record.serialize());
  }

  /// Starts the login process.
  ///
  /// Returns the login request (KE1) to send to the server
  /// and the client state needed to finish login.
  LoginStartResult loginStart(String password) {
    final client = OpaqueClient(_config);
    final ke1 = client.authInit(password);
    return LoginStartResult(
      request: Uint8List.fromList(ke1.serialize()),
      client: client,
    );
  }

  /// Finishes the login process.
  ///
  /// Takes the server's KE2 response and returns the KE3 message
  /// to send to the server along with the derived session and export keys.
  LoginFinishResult loginFinish(OpaqueClient client, Uint8List serverKe2) {
    final ke2 = KE2.deserialize(_config, serverKe2.toList());
    final result = client.authFinish(ke2);
    return LoginFinishResult(
      finishRequest: Uint8List.fromList(result.ke3.serialize()),
      sessionKey: Uint8List.fromList(result.sessionKey),
      exportKey: Uint8List.fromList(result.exportKey),
    );
  }
}
