// Copyright (c) 2021 Cloudflare, Inc. and contributors.
// Ported to Dart for Ratchet-Chat Flutter client.
// Licensed under the BSD-3-Clause license.

import 'dart:typed_data';

import 'common.dart';
import 'config.dart';
import 'crypto.dart';
import 'messages.dart';
import 'util.dart';

/// Cleartext credentials for envelope authentication.
class CleartextCredentials {
  final Uint8List serverPublicKey;
  final Uint8List serverIdentity;
  final Uint8List clientIdentity;

  CleartextCredentials({
    required this.serverPublicKey,
    required this.serverIdentity,
    required this.clientIdentity,
  });

  List<int> serialize() {
    return joinAll([
      serverPublicKey,
      encodeVector16(serverIdentity),
      encodeVector16(clientIdentity),
    ]).toList();
  }
}

/// Expand randomized password to derive keys.
({
  Uint8List authKey,
  Uint8List exportKey,
  AkeKeyPair clientAkeKeyPair,
}) _expandKeys(
  OpaqueConfig cfg,
  Uint8List randomizedPwd,
  Uint8List envelopeNonce,
) {
  final authKey = cfg.kdf.expand(
    randomizedPwd,
    joinAll([envelopeNonce, Labels.authKey]),
    cfg.hash.Nh,
  );
  final exportKey = cfg.kdf.expand(
    randomizedPwd,
    joinAll([envelopeNonce, Labels.exportKey]),
    cfg.hash.Nh,
  );
  final seed = cfg.kdf.expand(
    randomizedPwd,
    joinAll([envelopeNonce, Labels.privateKey]),
    cfg.constants.Nseed,
  );
  final clientAkeKeyPair = cfg.ake.deriveAuthKeyPair(seed);

  return (
    authKey: authKey,
    exportKey: exportKey,
    clientAkeKeyPair: clientAkeKeyPair,
  );
}

/// Store credentials in an envelope.
({
  Envelope envelope,
  Uint8List clientPublicKey,
  Uint8List maskingKey,
  Uint8List exportKey,
}) _store(
  OpaqueConfig cfg,
  Uint8List randomizedPwd,
  Uint8List serverPublicKey,
  Uint8List? serverIdentity,
  Uint8List? clientIdentity,
) {
  final envelopeNonce = Uint8List.fromList(cfg.prng.random(cfg.constants.Nn));
  final expanded = _expandKeys(cfg, randomizedPwd, envelopeNonce);

  final clientPublicKey = expanded.clientAkeKeyPair.publicKey;
  final cleartextCreds = CleartextCredentials(
    serverPublicKey: serverPublicKey,
    serverIdentity: serverIdentity ?? serverPublicKey,
    clientIdentity: clientIdentity ?? clientPublicKey,
  );

  final authMsg = joinAll([
    envelopeNonce,
    Uint8List.fromList(cleartextCreds.serialize()),
  ]);
  final authTag = cfg.mac.withKey(expanded.authKey).sign(authMsg);
  final envelope = Envelope(nonce: envelopeNonce, authTag: authTag);

  final maskingKey = cfg.kdf.expand(
    randomizedPwd,
    Labels.maskingKey,
    cfg.hash.Nh,
  );

  return (
    envelope: envelope,
    clientPublicKey: clientPublicKey,
    maskingKey: maskingKey,
    exportKey: expanded.exportKey,
  );
}

/// Recover credentials from an envelope.
({
  AkeKeyPair clientAkeKeyPair,
  Uint8List exportKey,
})? _recover(
  OpaqueConfig cfg,
  Envelope envelope,
  Uint8List randomizedPwd,
  Uint8List serverPublicKey,
  Uint8List? serverIdentity,
  Uint8List? clientIdentity,
) {
  final expanded = _expandKeys(cfg, randomizedPwd, envelope.nonce);
  final clientPublicKey = expanded.clientAkeKeyPair.publicKey;

  final cleartextCreds = CleartextCredentials(
    serverPublicKey: serverPublicKey,
    serverIdentity: serverIdentity ?? serverPublicKey,
    clientIdentity: clientIdentity ?? clientPublicKey,
  );

  final authMsg = joinAll([
    envelope.nonce,
    Uint8List.fromList(cleartextCreds.serialize()),
  ]);

  final macValid = cfg.mac.withKey(expanded.authKey).verify(
    authMsg,
    envelope.authTag,
  );

  if (!macValid) {
    return null; // Envelope recovery error
  }

  return (
    clientAkeKeyPair: expanded.clientAkeKeyPair,
    exportKey: expanded.exportKey,
  );
}

/// Core OPAQUE client operations.
class OpaqueCoreClient {
  final OpaqueConfig config;
  final MemHardFn memHard;

  OpaqueCoreClient(this.config, [MemHardFn? memHard])
      : memHard = memHard ?? ScryptMemHardFn();

  /// Create a registration request.
  ({RegistrationRequest request, Uint8List blind}) createRegistrationRequest(
    Uint8List password,
  ) {
    final blindResult = config.oprf.blind(password);
    final request = RegistrationRequest(data: blindResult.blindedElement);
    return (request: request, blind: blindResult.blind);
  }

  /// Finalize registration and create the registration record.
  ({RegistrationRecord record, List<int> exportKey}) finalizeRequest(
    Uint8List password,
    Uint8List blind,
    RegistrationResponse response,
    Uint8List? serverIdentity,
    Uint8List? clientIdentity,
  ) {
    final y = config.oprf.finalize(password, blind, response.evaluation);
    final hardened = memHard.harden(y);
    final nosalt = Uint8List(config.hash.Nh);
    final randomizedPwd = config.kdf.extract(
      nosalt,
      joinAll([y, hardened]),
    );
    final stored = _store(
      config,
      randomizedPwd,
      response.serverPublicKey,
      serverIdentity,
      clientIdentity,
    );

    final record = RegistrationRecord(
      clientPublicKey: stored.clientPublicKey,
      maskingKey: stored.maskingKey,
      envelope: stored.envelope,
    );

    return (record: record, exportKey: stored.exportKey.toList());
  }

  /// Create a credential request.
  ({CredentialRequest request, Uint8List blind}) createCredentialRequest(
    Uint8List password,
  ) {
    final blindResult = config.oprf.blind(password);
    final request = CredentialRequest(data: blindResult.blindedElement);
    return (request: request, blind: blindResult.blind);
  }

  /// Recover credentials from server response.
  ({
    Uint8List serverPublicKey,
    AkeKeyPair clientAkeKeyPair,
    Uint8List exportKey,
  })? recoverCredentials(
    Uint8List password,
    Uint8List blind,
    CredentialResponse response,
    Uint8List? serverIdentity,
    Uint8List? clientIdentity,
  ) {
    final y = config.oprf.finalize(password, blind, response.evaluation);
    final hardened = memHard.harden(y);
    final nosalt = Uint8List(config.hash.Nh);
    final randomizedPwd = config.kdf.extract(
      nosalt,
      joinAll([y, hardened]),
    );

    final maskingKey = config.kdf.expand(
      randomizedPwd,
      Labels.maskingKey,
      config.hash.Nh,
    );

    final Ne = Envelope.sizeSerialized(config);
    final credentialResponsePad = config.kdf.expand(
      maskingKey,
      joinAll([response.maskingNonce, Labels.credentialResponsePad]),
      config.ake.Npk + Ne,
    );

    final serverPubKeyEnve = xor(credentialResponsePad, response.maskedResponse);
    final serverPublicKey = serverPubKeyEnve.sublist(0, config.ake.Npk);
    final envelopeBytes = serverPubKeyEnve.sublist(config.ake.Npk, config.ake.Npk + Ne);
    final envelope = Envelope.deserialize(config, envelopeBytes.toList());

    final recovered = _recover(
      config,
      envelope,
      randomizedPwd,
      serverPublicKey,
      serverIdentity,
      clientIdentity,
    );

    if (recovered == null) {
      return null;
    }

    return (
      serverPublicKey: serverPublicKey,
      clientAkeKeyPair: recovered.clientAkeKeyPair,
      exportKey: recovered.exportKey,
    );
  }
}
