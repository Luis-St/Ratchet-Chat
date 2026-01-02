// Copyright (c) 2021 Cloudflare, Inc. and contributors.
// Ported to Dart for Ratchet-Chat Flutter client.
// Licensed under the BSD-3-Clause license.

import 'dart:typed_data';

import 'config.dart';
import 'messages.dart';
import 'oprf.dart';
import 'util.dart';

/// OPAQUE protocol labels.
class Labels {
  static final Uint8List authKey = encodeString('AuthKey');
  static final Uint8List clientMac = encodeString('ClientMAC');
  static final Uint8List credentialResponsePad =
      encodeString('CredentialResponsePad');
  static final Uint8List exportKey = encodeString('ExportKey');
  static final Uint8List handshakeSecret = encodeString('HandshakeSecret');
  static final Uint8List maskingKey = encodeString('MaskingKey');
  static final Uint8List opaque = encodeString('OPAQUE-');
  static final Uint8List opaqueDeriveAuthKeyPair =
      encodeString('OPAQUE-DeriveAuthKeyPair');
  static final Uint8List opaqueDeriveKeyPair =
      encodeString('OPAQUE-DeriveKeyPair');
  static final Uint8List oprfKey = encodeString('OprfKey');
  static final Uint8List privateKey = encodeString('PrivateKey');
  static final Uint8List rfc = encodeString('RFC9497');
  static final Uint8List serverMac = encodeString('ServerMAC');
  static final Uint8List sessionKey = encodeString('SessionKey');
}

/// Key pair for authentication.
class AkeKeyPair {
  final Uint8List privateKey;
  final Uint8List publicKey;

  AkeKeyPair({required this.privateKey, required this.publicKey});
}

/// AKE 3DH implementation for P-256.
class Ake3DH {
  final OprfId oprfId;

  /// Public key size.
  int get Npk => P256Oprf.Npk;

  /// Secret key size.
  int get Nsk => P256Oprf.Nsk;

  Ake3DH(this.oprfId);

  /// Derive authentication key pair from seed.
  AkeKeyPair deriveAuthKeyPair(Uint8List seed) {
    final scalar = P256Oprf.hashToScalar(seed, Labels.opaqueDeriveAuthKeyPair);
    final privateKey = P256Oprf.serializeScalar(scalar);
    final publicPoint = P256Oprf.scalarMult(P256Oprf.generator, scalar);
    final publicKey = P256Oprf.serializePoint(publicPoint);
    return AkeKeyPair(privateKey: privateKey, publicKey: publicKey);
  }

  /// Recover public key from private key.
  AkeKeyPair recoverPublicKey(Uint8List privateKey) {
    final scalar = P256Oprf.deserializeScalar(privateKey);
    final publicPoint = P256Oprf.scalarMult(P256Oprf.generator, scalar);
    final publicKey = P256Oprf.serializePoint(publicPoint);
    return AkeKeyPair(privateKey: privateKey, publicKey: publicKey);
  }

  /// Generate random authentication key pair.
  AkeKeyPair generateAuthKeyPair() {
    final scalar = P256Oprf.randomScalar();
    final privateKey = P256Oprf.serializeScalar(scalar);
    final publicPoint = P256Oprf.scalarMult(P256Oprf.generator, scalar);
    final publicKey = P256Oprf.serializePoint(publicPoint);
    return AkeKeyPair(privateKey: privateKey, publicKey: publicKey);
  }
}

/// Compute ECDH shared secret.
Uint8List ecdhSharedSecret(Uint8List privateKey, Uint8List publicKey) {
  final scalar = P256Oprf.deserializeScalar(privateKey);
  final point = P256Oprf.deserializePoint(publicKey);
  final shared = P256Oprf.scalarMult(point, scalar);
  return P256Oprf.serializePoint(shared);
}

/// Compute Triple-DH IKM (Input Key Material).
Uint8List tripleDhIkm(
  OpaqueConfig cfg,
  List<({Uint8List sk, Uint8List pk})> keys,
) {
  final ikm = <Uint8List>[];
  for (final key in keys) {
    final shared = ecdhSharedSecret(key.sk, key.pk);
    ikm.add(shared);
  }
  return joinAll(ikm);
}

/// Build the preamble for key derivation.
Uint8List preambleBuild(
  KE1 ke1,
  KE2 ke2,
  Uint8List serverIdentity,
  Uint8List clientIdentity,
  Uint8List context,
) {
  return joinAll([
    Labels.rfc,
    encodeVector16(context),
    encodeVector16(clientIdentity),
    Uint8List.fromList(ke1.serialize()),
    encodeVector16(serverIdentity),
    Uint8List.fromList(ke2.response.serialize()),
    ke2.authResponse.serverNonce,
    ke2.authResponse.serverKeyshare,
  ]);
}

/// Expand label for TLS-style key derivation.
Uint8List expandLabel(
  OpaqueConfig cfg,
  Uint8List secret,
  Uint8List label,
  Uint8List context,
  int length,
) {
  final customLabel = joinAll([
    encodeNumber(length, 16),
    encodeVector8(joinAll([Labels.opaque, label])),
    encodeVector8(context),
  ]);
  return cfg.kdf.expand(secret, customLabel, length);
}

/// Derive a secret from PRK.
Uint8List deriveSecret(
  OpaqueConfig cfg,
  Uint8List secret,
  Uint8List label,
  Uint8List transHash,
) {
  return expandLabel(cfg, secret, label, transHash, cfg.kdf.Nx);
}

/// Derive session keys from IKM and preamble.
({Uint8List km2, Uint8List km3, Uint8List sessionKey}) deriveKeys(
  OpaqueConfig cfg,
  Uint8List ikm,
  Uint8List preamble,
) {
  final nosalt = Uint8List(cfg.hash.Nh);
  final prk = cfg.kdf.extract(nosalt, ikm);
  final hPreamble = cfg.hash.sum(preamble);
  final handshakeSecret =
      deriveSecret(cfg, prk, Labels.handshakeSecret, hPreamble);
  final sessionKey = deriveSecret(cfg, prk, Labels.sessionKey, hPreamble);
  final noTranscript = Uint8List(0);
  final km2 = deriveSecret(cfg, handshakeSecret, Labels.serverMac, noTranscript);
  final km3 = deriveSecret(cfg, handshakeSecret, Labels.clientMac, noTranscript);
  return (km2: km2, km3: km3, sessionKey: sessionKey);
}
