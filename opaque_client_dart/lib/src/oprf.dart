// Copyright (c) 2021 Cloudflare, Inc. and contributors.
// Ported to Dart for Ratchet-Chat Flutter client.
// Licensed under the BSD-3-Clause license.

import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'crypto.dart';
import 'util.dart';

/// OPRF suite identifiers matching @cloudflare/voprf-ts
enum OprfId {
  oprfP256Sha256(0x0003, 'OPRF(P-256, SHA-256)'),
  oprfP384Sha384(0x0004, 'OPRF(P-384, SHA-384)'),
  oprfP521Sha512(0x0005, 'OPRF(P-521, SHA-512)');

  final int value;
  final String description;

  const OprfId(this.value, this.description);
}

/// P-256 curve parameters and operations for OPRF.
class P256Oprf {
  static final ECDomainParameters _params = ECCurve_secp256r1();
  static final Prng _prng = Prng();

  /// Size of a serialized element (compressed point).
  static const int Noe = 33; // Compressed P-256 point

  /// Size of a serialized scalar.
  static const int Nsk = 32;

  /// Size of public key.
  static const int Npk = 33;

  /// Hash function used with P-256 OPRF.
  static final HashId hashId = HashId.sha256;

  /// Get the curve order.
  static BigInt get order => _params.n;

  /// Get the generator point.
  static ECPoint get generator => _params.G;

  /// Generate a random scalar in the valid range.
  static BigInt randomScalar() {
    final bytes = _prng.random(32);
    var scalar = _bytesToBigInt(bytes) % order;
    // Ensure non-zero
    while (scalar == BigInt.zero) {
      final newBytes = _prng.random(32);
      scalar = _bytesToBigInt(newBytes) % order;
    }
    return scalar;
  }

  /// Convert bytes to BigInt (big-endian).
  static BigInt _bytesToBigInt(Uint8List bytes) {
    BigInt result = BigInt.zero;
    for (int i = 0; i < bytes.length; i++) {
      result = (result << 8) | BigInt.from(bytes[i]);
    }
    return result;
  }

  /// Convert BigInt to fixed-size bytes (big-endian).
  static Uint8List _bigIntToBytes(BigInt value, int length) {
    final result = Uint8List(length);
    var temp = value;
    for (int i = length - 1; i >= 0; i--) {
      result[i] = (temp & BigInt.from(0xff)).toInt();
      temp = temp >> 8;
    }
    return result;
  }

  /// Serialize a scalar to bytes.
  static Uint8List serializeScalar(BigInt scalar) {
    return _bigIntToBytes(scalar, Nsk);
  }

  /// Deserialize bytes to a scalar.
  static BigInt deserializeScalar(Uint8List bytes) {
    if (bytes.length != Nsk) {
      throw ArgumentError('Invalid scalar length');
    }
    return _bytesToBigInt(bytes);
  }

  /// Serialize a point to compressed format.
  static Uint8List serializePoint(ECPoint point) {
    return Uint8List.fromList(point.getEncoded(true));
  }

  /// Deserialize a compressed point.
  static ECPoint deserializePoint(Uint8List bytes) {
    final point = _params.curve.decodePoint(bytes);
    if (point == null) {
      throw ArgumentError('Invalid point encoding');
    }
    return point;
  }

  /// Scalar multiplication: point * scalar
  static ECPoint scalarMult(ECPoint point, BigInt scalar) {
    return (point * scalar)!;
  }

  /// Hash to curve using the simplified SWU method for P-256.
  /// This implements draft-irtf-cfrg-hash-to-curve.
  static ECPoint hashToCurve(Uint8List input, Uint8List dst) {
    // Use hash-to-field to get two field elements
    final u = _hashToField(input, dst, 2);

    // Map each field element to a curve point
    final q0 = _mapToCurve(u[0]);
    final q1 = _mapToCurve(u[1]);

    // Add the points
    final r = (q0 + q1)!;

    // Clear cofactor (P-256 has cofactor 1, so this is identity)
    return r;
  }

  /// Hash to field elements using expand_message_xmd.
  static List<BigInt> _hashToField(Uint8List input, Uint8List dst, int count) {
    // P-256 prime (field size) - get from curve's a coefficient
    final BigInt p = (_params.curve.a as dynamic).q as BigInt;
    const int L = 48; // ceil((256 + 128) / 8)

    final lenInBytes = count * L;
    final uniformBytes = _expandMessageXmd(input, dst, lenInBytes);

    final result = <BigInt>[];
    for (int i = 0; i < count; i++) {
      final offset = i * L;
      final tv = uniformBytes.sublist(offset, offset + L);
      final e = _bytesToBigInt(tv) % p;
      result.add(e);
    }
    return result;
  }

  /// expand_message_xmd using SHA-256.
  static Uint8List _expandMessageXmd(
      Uint8List msg, Uint8List dst, int lenInBytes) {
    final hash = Hash(HashId.sha256);
    const bInBytes = 32; // SHA-256 output size
    const sInBytes = 64; // SHA-256 block size

    final ell = (lenInBytes + bInBytes - 1) ~/ bInBytes;
    if (ell > 255) {
      throw ArgumentError('lenInBytes too large');
    }
    if (dst.length > 255) {
      throw ArgumentError('DST too long');
    }

    final dstPrime = joinAll([dst, Uint8List.fromList([dst.length])]);
    final zPad = Uint8List(sInBytes);
    final libStr = Uint8List.fromList([(lenInBytes >> 8) & 0xff, lenInBytes & 0xff]);

    final msgPrime = joinAll([zPad, msg, libStr, Uint8List.fromList([0]), dstPrime]);
    final b0 = hash.sum(msgPrime);

    final b1Input = joinAll([b0, Uint8List.fromList([1]), dstPrime]);
    var bi = hash.sum(b1Input);

    final uniformBytes = Uint8List(lenInBytes);
    uniformBytes.setAll(0, bi.sublist(0, lenInBytes < bInBytes ? lenInBytes : bInBytes));

    for (int i = 2; i <= ell; i++) {
      final biInput = joinAll([xor(b0, bi), Uint8List.fromList([i]), dstPrime]);
      bi = hash.sum(biInput);
      final start = (i - 1) * bInBytes;
      final end = start + bInBytes;
      if (end <= lenInBytes) {
        uniformBytes.setAll(start, bi);
      } else {
        uniformBytes.setAll(start, bi.sublist(0, lenInBytes - start));
      }
    }

    return uniformBytes;
  }

  /// Simplified SWU map to curve for P-256.
  /// Implements draft-irtf-cfrg-hash-to-curve simplified SWU method.
  static ECPoint _mapToCurve(BigInt u) {
    final BigInt p = (_params.curve.a as dynamic).q as BigInt;
    final BigInt a = _params.curve.a!.toBigInteger()!;
    final BigInt b = _params.curve.b!.toBigInteger()!;

    // Z = -10 for P-256 (satisfies criteria: non-square, Z != -1, etc.)
    final BigInt z = (p - BigInt.from(10)) % p;

    // c1 = (p + 1) / 4  (for sqrt since p = 3 mod 4)
    final BigInt c1 = (p + BigInt.one) ~/ BigInt.from(4);

    // c2 = sqrt(-Z^3) - precomputed for efficiency
    final BigInt negZ = (p - z) % p;
    final BigInt negZCubed = negZ.modPow(BigInt.from(3), p);
    final BigInt c2 = negZCubed.modPow(c1, p);

    // tv1 = Z * u^2
    final BigInt tv1 = (z * u.modPow(BigInt.two, p)) % p;

    // tv2 = tv1^2 + tv1
    final BigInt tv2 = (tv1.modPow(BigInt.two, p) + tv1) % p;

    // x1 = (-b / a) * (1 + 1/(tv2))  when tv2 != 0
    // x1 = -b / (Z * a)              when tv2 == 0
    BigInt x1;
    if (tv2 == BigInt.zero) {
      // x1 = -b / (Z * a)
      final BigInt denom = (z * a) % p;
      x1 = ((p - b) * denom.modInverse(p)) % p;
    } else {
      // x1 = (-b / a) * (1 + 1/tv2)
      // x1 = (-b / a) * (tv2 + 1) / tv2
      final BigInt negBOverA = ((p - b) * a.modInverse(p)) % p;
      final BigInt tv2Plus1 = (tv2 + BigInt.one) % p;
      x1 = (negBOverA * tv2Plus1 * tv2.modInverse(p)) % p;
    }

    // gx1 = x1^3 + a*x1 + b
    final BigInt gx1 = (x1.modPow(BigInt.from(3), p) + (a * x1) % p + b) % p;

    // x2 = Z * u^2 * x1 = tv1 * x1
    final BigInt x2 = (tv1 * x1) % p;

    // gx2 = x2^3 + a*x2 + b
    final BigInt gx2 = (x2.modPow(BigInt.from(3), p) + (a * x2) % p + b) % p;

    // Choose x and compute y
    BigInt x, y;
    if (_isSquare(gx1, p)) {
      x = x1;
      y = gx1.modPow(c1, p);
    } else {
      x = x2;
      y = gx2.modPow(c1, p);
    }

    // Negate y if sign doesn't match u
    // sgn0(y) should equal sgn0(u)
    if (y.isOdd != u.isOdd) {
      y = (p - y) % p;
    }

    return _params.curve.createPoint(x, y);
  }

  /// Check if a value is a quadratic residue mod p.
  static bool _isSquare(BigInt a, BigInt p) {
    final exp = (p - BigInt.one) ~/ BigInt.two;
    return a.modPow(exp, p) == BigInt.one;
  }

  /// Compute modular square root using Tonelli-Shanks.
  static BigInt? _modSqrt(BigInt a, BigInt p) {
    if (a == BigInt.zero) return BigInt.zero;
    if (!_isSquare(a, p)) return null;

    // For p = 3 mod 4 (which P-256 satisfies)
    final exp = (p + BigInt.one) ~/ BigInt.from(4);
    return a.modPow(exp, p);
  }

  /// Compute modular inverse.
  static BigInt _modInverse(BigInt a, BigInt p) {
    return a.modInverse(p);
  }

  /// Hash to scalar for key derivation.
  static BigInt hashToScalar(Uint8List input, Uint8List dst) {
    final u = _hashToField(input, dst, 1);
    return u[0] % order;
  }
}

/// Result of OPRF blind operation.
class BlindResult {
  final Uint8List blind;
  final Uint8List blindedElement;

  BlindResult({required this.blind, required this.blindedElement});
}

/// OPRF client for P-256.
class OprfClient {
  final OprfId id;

  /// Size of serialized element.
  int get Noe => P256Oprf.Noe;

  /// Hash function used.
  HashId get hashId => P256Oprf.hashId;

  OprfClient(this.id) {
    if (id != OprfId.oprfP256Sha256) {
      throw UnimplementedError('Only P-256 OPRF is implemented');
    }
  }

  /// Build the HashToGroup DST according to RFC 9497.
  /// Format: "HashToGroup-" + contextString
  /// contextString = "OPRFV1-" + I2OSP(mode, 1) + "-" + identifier
  Uint8List _buildHashToGroupDST() {
    // For OPRF mode (0x00) with P256-SHA256:
    // contextString = "OPRFV1-" + 0x00 + "-P256-SHA256"
    // DST = "HashToGroup-" + contextString
    const mode = 0x00; // modeOPRF
    const identifier = 'P256-SHA256';
    final prefix = 'HashToGroup-OPRFV1-'.codeUnits;
    final suffix = '-$identifier'.codeUnits;
    return Uint8List.fromList([...prefix, mode, ...suffix]);
  }

  /// Blind an input.
  BlindResult blind(Uint8List input) {
    // Generate random blind
    final r = P256Oprf.randomScalar();

    // Hash input to curve point using RFC 9497 compliant DST
    final dst = _buildHashToGroupDST();
    final point = P256Oprf.hashToCurve(input, dst);

    // Blind the point: M = r * P
    final blinded = P256Oprf.scalarMult(point, r);

    return BlindResult(
      blind: P256Oprf.serializeScalar(r),
      blindedElement: P256Oprf.serializePoint(blinded),
    );
  }

  /// Finalize the OPRF output.
  Uint8List finalize(Uint8List input, Uint8List blind, Uint8List evaluation) {
    // Deserialize blind and evaluation
    final r = P256Oprf.deserializeScalar(blind);
    final z = P256Oprf.deserializePoint(evaluation);

    // Unblind: Z / r = Z * r^(-1)
    final rInv = r.modInverse(P256Oprf.order);
    final n = P256Oprf.scalarMult(z, rInv);

    // Hash the result
    final hash = Hash(P256Oprf.hashId);
    final encodedElement = P256Oprf.serializePoint(n);
    return hash.sum(joinAll([
      encodeVector16(input),
      encodeVector16(encodedElement),
      Uint8List.fromList('Finalize'.codeUnits),
    ]));
  }
}

/// OPRF mode for OPAQUE using P-256.
class OprfBaseMode {
  final OprfId id;
  final OprfClient _client;

  /// Size of serialized OPRF element.
  int get Noe => P256Oprf.Noe;

  /// Hash function used.
  HashId get hashId => P256Oprf.hashId;

  String get name => id.description;

  OprfBaseMode(this.id) : _client = OprfClient(id);

  /// Blind an input.
  BlindResult blind(Uint8List input) {
    return _client.blind(input);
  }

  /// Finalize the OPRF output.
  Uint8List finalize(Uint8List input, Uint8List blind, Uint8List evaluation) {
    return _client.finalize(input, blind, evaluation);
  }

  /// Derive OPRF key from seed.
  Uint8List deriveOprfKey(Uint8List seed) {
    final dst = Uint8List.fromList('OPAQUE-DeriveKeyPair'.codeUnits);
    final scalar = P256Oprf.hashToScalar(seed, dst);
    return P256Oprf.serializeScalar(scalar);
  }
}
