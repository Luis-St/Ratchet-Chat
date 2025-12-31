// Copyright (c) 2021 Cloudflare, Inc. and contributors.
// Ported to Dart for Ratchet-Chat Flutter client.
// Licensed under the BSD-3-Clause license.

import 'common.dart';
import 'crypto.dart';
import 'oprf.dart';

/// OPAQUE suite identifiers.
enum OpaqueId {
  opaqueP256(3, 'OPAQUE-P256'),
  opaqueP384(4, 'OPAQUE-P384'),
  opaqueP521(5, 'OPAQUE-P521');

  final int value;
  final String name;

  const OpaqueId(this.value, this.name);
}

/// OPAQUE protocol constants.
class OpaqueConstants {
  /// Nonce length in bytes.
  final int Nn = 32;

  /// Seed length in bytes.
  final int Nseed = 32;
}

/// OPAQUE configuration for a specific suite.
class OpaqueConfig {
  final OpaqueId opaqueId;
  final OpaqueConstants constants;
  final Prng prng;
  final OprfBaseMode oprf;
  final Hash hash;
  final Hmac mac;
  final Hkdf kdf;
  final Ake3DH ake;

  OpaqueConfig._(
    this.opaqueId,
    this.constants,
    this.prng,
    this.oprf,
    this.hash,
    this.mac,
    this.kdf,
    this.ake,
  );

  factory OpaqueConfig(OpaqueId opaqueId) {
    OprfId oprfId;
    switch (opaqueId) {
      case OpaqueId.opaqueP256:
        oprfId = OprfId.oprfP256Sha256;
      case OpaqueId.opaqueP384:
        oprfId = OprfId.oprfP384Sha384;
      case OpaqueId.opaqueP521:
        oprfId = OprfId.oprfP521Sha512;
    }

    final constants = OpaqueConstants();
    final prng = Prng();
    final oprf = OprfBaseMode(oprfId);
    final hash = Hash(oprf.hashId);
    final mac = Hmac(oprf.hashId);
    final kdf = Hkdf(oprf.hashId);
    final ake = Ake3DH(oprfId);

    return OpaqueConfig._(
      opaqueId,
      constants,
      prng,
      oprf,
      hash,
      mac,
      kdf,
      ake,
    );
  }

  @override
  String toString() {
    return '${opaqueId.name} = {OPRF: ${oprf.name}, Hash: ${hash.name}}';
  }
}

/// Get OPAQUE configuration for a specific suite.
OpaqueConfig getOpaqueConfig(OpaqueId opaqueId) {
  return OpaqueConfig(opaqueId);
}
