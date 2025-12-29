// Copyright (c) 2021 Cloudflare, Inc. and contributors.
// Ported to Dart for Ratchet-Chat Flutter client.
// Licensed under the BSD-3-Clause license.

import 'dart:typed_data';

import 'config.dart';
import 'util.dart';

/// Envelope containing authentication data.
class Envelope {
  final Uint8List nonce;
  final Uint8List authTag;

  Envelope({required this.nonce, required this.authTag});

  /// Serialize envelope to bytes.
  List<int> serialize() {
    return joinAll([nonce, authTag]).toList();
  }

  /// Get serialized size.
  static int sizeSerialized(OpaqueConfig cfg) {
    return cfg.constants.Nn + cfg.mac.Nm;
  }

  /// Deserialize envelope from bytes.
  static Envelope deserialize(OpaqueConfig cfg, List<int> bytes) {
    final u8array = Uint8List.fromList(bytes);
    if (u8array.length < sizeSerialized(cfg)) {
      throw ArgumentError('Envelope too short');
    }

    int start = 0;
    int end = cfg.constants.Nn;
    final nonce = u8array.sublist(start, end);

    start = end;
    end += cfg.mac.Nm;
    final authTag = u8array.sublist(start, end);

    return Envelope(nonce: nonce, authTag: authTag);
  }
}

/// Registration request from client to server.
class RegistrationRequest {
  final Uint8List data;

  RegistrationRequest({required this.data});

  /// Serialize to bytes.
  List<int> serialize() {
    return data.toList();
  }

  /// Get serialized size.
  static int sizeSerialized(OpaqueConfig cfg) {
    return cfg.oprf.Noe;
  }

  /// Deserialize from bytes.
  static RegistrationRequest deserialize(OpaqueConfig cfg, List<int> bytes) {
    final u8array = Uint8List.fromList(bytes);
    if (u8array.length < sizeSerialized(cfg)) {
      throw ArgumentError('RegistrationRequest too short');
    }
    return RegistrationRequest(data: u8array.sublist(0, cfg.oprf.Noe));
  }
}

/// Registration response from server to client.
class RegistrationResponse {
  final Uint8List evaluation;
  final Uint8List serverPublicKey;

  RegistrationResponse({
    required this.evaluation,
    required this.serverPublicKey,
  });

  /// Serialize to bytes.
  List<int> serialize() {
    return joinAll([evaluation, serverPublicKey]).toList();
  }

  /// Get serialized size.
  static int sizeSerialized(OpaqueConfig cfg) {
    return cfg.oprf.Noe + cfg.ake.Npk;
  }

  /// Deserialize from bytes.
  static RegistrationResponse deserialize(OpaqueConfig cfg, List<int> bytes) {
    final u8array = Uint8List.fromList(bytes);
    if (u8array.length < sizeSerialized(cfg)) {
      throw ArgumentError('RegistrationResponse too short');
    }

    int start = 0;
    int end = cfg.oprf.Noe;
    final evaluation = u8array.sublist(start, end);

    start = end;
    end += cfg.ake.Npk;
    final serverPublicKey = u8array.sublist(start, end);

    return RegistrationResponse(
      evaluation: evaluation,
      serverPublicKey: serverPublicKey,
    );
  }
}

/// Registration record stored by server.
class RegistrationRecord {
  final Uint8List clientPublicKey;
  final Uint8List maskingKey;
  final Envelope envelope;

  RegistrationRecord({
    required this.clientPublicKey,
    required this.maskingKey,
    required this.envelope,
  });

  /// Serialize to bytes.
  List<int> serialize() {
    return joinAll([
      clientPublicKey,
      maskingKey,
      Uint8List.fromList(envelope.serialize()),
    ]).toList();
  }

  /// Get serialized size.
  static int sizeSerialized(OpaqueConfig cfg) {
    return cfg.ake.Npk + cfg.hash.Nh + Envelope.sizeSerialized(cfg);
  }

  /// Deserialize from bytes.
  static RegistrationRecord deserialize(OpaqueConfig cfg, List<int> bytes) {
    final u8array = Uint8List.fromList(bytes);
    if (u8array.length < sizeSerialized(cfg)) {
      throw ArgumentError('RegistrationRecord too short');
    }

    int start = 0;
    int end = cfg.ake.Npk;
    final clientPublicKey = u8array.sublist(start, end);

    start = end;
    end += cfg.hash.Nh;
    final maskingKey = u8array.sublist(start, end);

    start = end;
    end += Envelope.sizeSerialized(cfg);
    final envelopeBytes = u8array.sublist(start, end);
    final envelope = Envelope.deserialize(cfg, envelopeBytes.toList());

    return RegistrationRecord(
      clientPublicKey: clientPublicKey,
      maskingKey: maskingKey,
      envelope: envelope,
    );
  }
}

/// Credential request from client to server.
class CredentialRequest {
  final Uint8List data;

  CredentialRequest({required this.data});

  /// Serialize to bytes.
  List<int> serialize() {
    return data.toList();
  }

  /// Get serialized size.
  static int sizeSerialized(OpaqueConfig cfg) {
    return cfg.oprf.Noe;
  }

  /// Deserialize from bytes.
  static CredentialRequest deserialize(OpaqueConfig cfg, List<int> bytes) {
    final u8array = Uint8List.fromList(bytes);
    if (u8array.length < sizeSerialized(cfg)) {
      throw ArgumentError('CredentialRequest too short');
    }
    return CredentialRequest(data: u8array.sublist(0, cfg.oprf.Noe));
  }
}

/// Credential response from server to client.
class CredentialResponse {
  final Uint8List evaluation;
  final Uint8List maskingNonce;
  final Uint8List maskedResponse;

  CredentialResponse({
    required this.evaluation,
    required this.maskingNonce,
    required this.maskedResponse,
  });

  /// Serialize to bytes.
  List<int> serialize() {
    return joinAll([evaluation, maskingNonce, maskedResponse]).toList();
  }

  /// Get serialized size.
  static int sizeSerialized(OpaqueConfig cfg) {
    return cfg.oprf.Noe +
        cfg.constants.Nn +
        cfg.ake.Npk +
        Envelope.sizeSerialized(cfg);
  }

  /// Deserialize from bytes.
  static CredentialResponse deserialize(OpaqueConfig cfg, List<int> bytes) {
    final u8array = Uint8List.fromList(bytes);
    if (u8array.length < sizeSerialized(cfg)) {
      throw ArgumentError('CredentialResponse too short');
    }

    int start = 0;
    int end = cfg.oprf.Noe;
    final evaluation = u8array.sublist(start, end);

    start = end;
    end += cfg.constants.Nn;
    final maskingNonce = u8array.sublist(start, end);

    start = end;
    end += cfg.ake.Npk + Envelope.sizeSerialized(cfg);
    final maskedResponse = u8array.sublist(start, end);

    return CredentialResponse(
      evaluation: evaluation,
      maskingNonce: maskingNonce,
      maskedResponse: maskedResponse,
    );
  }
}

/// Authentication initialization message.
class AuthInit {
  final Uint8List clientNonce;
  final Uint8List clientKeyshare;

  AuthInit({required this.clientNonce, required this.clientKeyshare});

  /// Serialize to bytes.
  List<int> serialize() {
    return joinAll([clientNonce, clientKeyshare]).toList();
  }

  /// Get serialized size.
  static int sizeSerialized(OpaqueConfig cfg) {
    return cfg.constants.Nn + cfg.ake.Npk;
  }

  /// Deserialize from bytes.
  static AuthInit deserialize(OpaqueConfig cfg, List<int> bytes) {
    final u8array = Uint8List.fromList(bytes);
    if (u8array.length < sizeSerialized(cfg)) {
      throw ArgumentError('AuthInit too short');
    }

    int start = 0;
    int end = cfg.constants.Nn;
    final clientNonce = u8array.sublist(start, end);

    start = end;
    end += cfg.ake.Npk;
    final clientKeyshare = u8array.sublist(start, end);

    return AuthInit(clientNonce: clientNonce, clientKeyshare: clientKeyshare);
  }
}

/// Authentication response from server.
class AuthResponse {
  final Uint8List serverNonce;
  final Uint8List serverKeyshare;
  final Uint8List serverMac;

  AuthResponse({
    required this.serverNonce,
    required this.serverKeyshare,
    required this.serverMac,
  });

  /// Serialize to bytes.
  List<int> serialize() {
    return joinAll([serverNonce, serverKeyshare, serverMac]).toList();
  }

  /// Get serialized size.
  static int sizeSerialized(OpaqueConfig cfg) {
    return cfg.constants.Nn + cfg.ake.Npk + cfg.mac.Nm;
  }

  /// Deserialize from bytes.
  static AuthResponse deserialize(OpaqueConfig cfg, List<int> bytes) {
    final u8array = Uint8List.fromList(bytes);
    if (u8array.length < sizeSerialized(cfg)) {
      throw ArgumentError('AuthResponse too short');
    }

    int start = 0;
    int end = cfg.constants.Nn;
    final serverNonce = u8array.sublist(start, end);

    start = end;
    end += cfg.ake.Npk;
    final serverKeyshare = u8array.sublist(start, end);

    start = end;
    end += cfg.mac.Nm;
    final serverMac = u8array.sublist(start, end);

    return AuthResponse(
      serverNonce: serverNonce,
      serverKeyshare: serverKeyshare,
      serverMac: serverMac,
    );
  }
}

/// Authentication finish message from client.
class AuthFinish {
  final Uint8List clientMac;

  AuthFinish({required this.clientMac});

  /// Serialize to bytes.
  List<int> serialize() {
    return clientMac.toList();
  }

  /// Get serialized size.
  static int sizeSerialized(OpaqueConfig cfg) {
    return cfg.mac.Nm;
  }

  /// Deserialize from bytes.
  static AuthFinish deserialize(OpaqueConfig cfg, List<int> bytes) {
    final u8array = Uint8List.fromList(bytes);
    if (u8array.length < sizeSerialized(cfg)) {
      throw ArgumentError('AuthFinish too short');
    }
    return AuthFinish(clientMac: u8array.sublist(0, cfg.mac.Nm));
  }
}

/// KE1: First key exchange message (client to server).
class KE1 {
  final CredentialRequest request;
  final AuthInit authInit;

  KE1({required this.request, required this.authInit});

  /// Serialize to bytes.
  List<int> serialize() {
    return [...request.serialize(), ...authInit.serialize()];
  }

  /// Get serialized size.
  static int sizeSerialized(OpaqueConfig cfg) {
    return CredentialRequest.sizeSerialized(cfg) +
        AuthInit.sizeSerialized(cfg);
  }

  /// Deserialize from bytes.
  static KE1 deserialize(OpaqueConfig cfg, List<int> bytes) {
    int start = 0;
    int end = CredentialRequest.sizeSerialized(cfg);
    final request = CredentialRequest.deserialize(cfg, bytes.sublist(start, end));

    start = end;
    end += AuthInit.sizeSerialized(cfg);
    final authInit = AuthInit.deserialize(cfg, bytes.sublist(start, end));

    return KE1(request: request, authInit: authInit);
  }
}

/// KE2: Second key exchange message (server to client).
class KE2 {
  final CredentialResponse response;
  final AuthResponse authResponse;

  KE2({required this.response, required this.authResponse});

  /// Serialize to bytes.
  List<int> serialize() {
    return [...response.serialize(), ...authResponse.serialize()];
  }

  /// Get serialized size.
  static int sizeSerialized(OpaqueConfig cfg) {
    return CredentialResponse.sizeSerialized(cfg) +
        AuthResponse.sizeSerialized(cfg);
  }

  /// Deserialize from bytes.
  static KE2 deserialize(OpaqueConfig cfg, List<int> bytes) {
    int start = 0;
    int end = CredentialResponse.sizeSerialized(cfg);
    final response = CredentialResponse.deserialize(cfg, bytes.sublist(start, end));

    start = end;
    end += AuthResponse.sizeSerialized(cfg);
    final authResponse = AuthResponse.deserialize(cfg, bytes.sublist(start, end));

    return KE2(response: response, authResponse: authResponse);
  }
}

/// KE3: Third key exchange message (client to server).
class KE3 {
  final AuthFinish authFinish;

  KE3({required this.authFinish});

  /// Serialize to bytes.
  List<int> serialize() {
    return authFinish.serialize();
  }

  /// Get serialized size.
  static int sizeSerialized(OpaqueConfig cfg) {
    return AuthFinish.sizeSerialized(cfg);
  }

  /// Deserialize from bytes.
  static KE3 deserialize(OpaqueConfig cfg, List<int> bytes) {
    final authFinish = AuthFinish.deserialize(cfg, bytes);
    return KE3(authFinish: authFinish);
  }
}
