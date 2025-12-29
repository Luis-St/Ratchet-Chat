// Copyright (c) 2021 Cloudflare, Inc. and contributors.
// Ported to Dart for Ratchet-Chat Flutter client.
// Licensed under the BSD-3-Clause license.

import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'util.dart';

/// Cryptographically secure random number generator.
class Prng {
  final SecureRandom _random;

  Prng() : _random = _createSecureRandom();

  static SecureRandom _createSecureRandom() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  /// Generate random bytes.
  Uint8List random(int numBytes) {
    return _random.nextBytes(numBytes);
  }
}

/// Hash function identifiers.
enum HashId {
  sha256('SHA-256', 32),
  sha384('SHA-384', 48),
  sha512('SHA-512', 64);

  final String name;
  final int hashLength;

  const HashId(this.name, this.hashLength);
}

/// Hash function wrapper.
class Hash {
  final HashId id;

  /// Hash output length in bytes.
  int get Nh => id.hashLength;

  String get name => id.name;

  Hash(this.id);

  /// Compute hash of message.
  Uint8List sum(Uint8List msg) {
    final Digest digest;
    switch (id) {
      case HashId.sha256:
        digest = SHA256Digest();
      case HashId.sha384:
        digest = SHA384Digest();
      case HashId.sha512:
        digest = SHA512Digest();
    }
    return digest.process(msg);
  }
}

/// HMAC wrapper.
class Hmac {
  final HashId hashId;

  /// MAC output length in bytes.
  int get Nm => hashId.hashLength;

  Hmac(this.hashId);

  /// Create HMAC instance with key.
  HmacOps withKey(Uint8List key) {
    return HmacOps(hashId, key);
  }
}

/// HMAC operations with a specific key.
class HmacOps {
  final HashId _hashId;
  final Uint8List _key;

  HmacOps(this._hashId, this._key);

  Mac _createMac() {
    final Digest digest;
    switch (_hashId) {
      case HashId.sha256:
        digest = SHA256Digest();
      case HashId.sha384:
        digest = SHA384Digest();
      case HashId.sha512:
        digest = SHA512Digest();
    }
    final hmac = HMac(digest, 64);
    hmac.init(KeyParameter(_key));
    return hmac;
  }

  /// Sign a message.
  Uint8List sign(Uint8List msg) {
    final hmac = _createMac();
    hmac.update(msg, 0, msg.length);
    final out = Uint8List(hmac.macSize);
    hmac.doFinal(out, 0);
    return out;
  }

  /// Verify a MAC.
  bool verify(Uint8List msg, Uint8List tag) {
    final expected = sign(msg);
    return ctEqual(expected, tag);
  }
}

/// HKDF (RFC 5869) implementation.
class Hkdf {
  final HashId hashId;

  /// Output key length (same as hash length).
  int get Nx => hashId.hashLength;

  Hkdf(this.hashId);

  /// HKDF-Extract: extract a pseudorandom key from input keying material.
  Uint8List extract(Uint8List salt, Uint8List ikm) {
    return Hmac(hashId).withKey(salt).sign(ikm);
  }

  /// HKDF-Expand: expand a pseudorandom key to desired length.
  Uint8List expand(Uint8List prk, Uint8List info, int length) {
    final hashLen = hashId.hashLength;
    final n = (length + hashLen - 1) ~/ hashLen;
    final t = Uint8List(n * hashLen);
    final hmac = Hmac(hashId).withKey(prk);
    Uint8List ti = Uint8List(0);
    int offset = 0;

    for (int i = 0; i < n; i++) {
      final input = joinAll([ti, info, Uint8List.fromList([i + 1])]);
      ti = hmac.sign(input);
      t.setAll(offset, ti);
      offset += hashLen;
    }

    return t.sublist(0, length);
  }
}

/// Memory-hard function interface.
abstract class MemHardFn {
  String get name;
  Uint8List harden(Uint8List input);
}

/// Identity memory-hard function (no hardening).
class IdentityMemHardFn implements MemHardFn {
  @override
  String get name => 'Identity';

  @override
  Uint8List harden(Uint8List input) => input;
}

/// Scrypt memory-hard function.
/// Parameters match @cloudflare/opaque-ts: N=32768, r=8, p=1
class ScryptMemHardFn implements MemHardFn {
  @override
  String get name => 'scrypt';

  @override
  Uint8List harden(Uint8List input) {
    // Using PointyCastle's Scrypt implementation
    // Parameters: N=32768 (2^15), r=8, p=1, dkLen=32
    final scrypt = Scrypt();
    scrypt.init(ScryptParameters(
      32768, // N (cost parameter)
      8, // r (block size)
      1, // p (parallelization)
      32, // dkLen (derived key length)
      Uint8List(0), // salt (empty as per opaque-ts)
    ));
    return scrypt.process(input);
  }
}
