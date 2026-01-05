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
  /// Implements RFC 9380 Appendix F.2 - must match @cloudflare/voprf-ts exactly.
  static ECPoint _mapToCurve(BigInt u) {
    final BigInt p = (_params.curve.a as dynamic).q as BigInt;
    final BigInt A = _params.curve.a!.toBigInteger()!;
    final BigInt B = _params.curve.b!.toBigInteger()!;

    // Constants matching @cloudflare/voprf-ts group.js line 57-60
    // Z = -10 for P-256
    final BigInt Z = (p - BigInt.from(10)) % p;
    // c1 = (p - 3) / 4  (NOT (p+1)/4!)
    final BigInt c1 = (p - BigInt.from(3)) ~/ BigInt.from(4);
    // c2 = precomputed sqrt(-Z^3) - must match @cloudflare/voprf-ts exactly
    final BigInt c2 = BigInt.parse(
      '78bc71a02d89ec07214623f6d0f955072c7cc05604a5a6e23ffbf67115fa5301',
      radix: 16,
    );

    final BigInt zero = BigInt.zero;
    final BigInt one = BigInt.one;

    // Helper: conditional move
    BigInt cmov(BigInt x, BigInt y, bool b) => b ? y : x;

    // Helper: sgn0 - returns 0 or 1 based on parity
    int sgn(BigInt x) => (x % BigInt.two).toInt();

    // RFC 9380 Appendix F.2 - Simplified SWU for AB != 0
    // Steps match @cloudflare/voprf-ts group.js sswu() exactly

    BigInt tv1 = (u * u) % p;                           // 1. tv1 = u^2
    BigInt tv3 = (Z * tv1) % p;                         // 2. tv3 = Z * tv1
    BigInt tv2 = (tv3 * tv3) % p;                       // 3. tv2 = tv3^2
    BigInt xd = (tv2 + tv3) % p;                        // 4. xd = tv2 + tv3
    BigInt x1n = (xd + one) % p;                        // 5. x1n = xd + 1
    x1n = (x1n * B) % p;                                // 6. x1n = x1n * B
    BigInt tv4 = (p - A) % p;                           // (compute -A)
    xd = (xd * tv4) % p;                                // 7. xd = -A * xd
    final bool e1 = xd == zero;                         // 8. e1 = xd == 0
    tv4 = (A * Z) % p;
    xd = cmov(xd, tv4, e1);                             // 9. xd = CMOV(xd, Z * A, e1)
    tv2 = (xd * xd) % p;                                // 10. tv2 = xd^2
    BigInt gxd = (tv2 * xd) % p;                        // 11. gxd = tv2 * xd
    tv2 = (A * tv2) % p;                                // 12. tv2 = A * tv2
    BigInt gx1 = (x1n * x1n) % p;                       // 13. gx1 = x1n^2
    gx1 = (gx1 + tv2) % p;                              // 14. gx1 = gx1 + tv2
    gx1 = (gx1 * x1n) % p;                              // 15. gx1 = gx1 * x1n
    tv2 = (B * gxd) % p;                                // 16. tv2 = B * gxd
    gx1 = (gx1 + tv2) % p;                              // 17. gx1 = gx1 + tv2
    tv4 = (gxd * gxd) % p;                              // 18. tv4 = gxd^2
    tv2 = (gx1 * gxd) % p;                              // 19. tv2 = gx1 * gxd
    tv4 = (tv4 * tv2) % p;                              // 20. tv4 = tv4 * tv2
    BigInt y1 = tv4.modPow(c1, p);                      // 21. y1 = tv4^c1
    y1 = (y1 * tv2) % p;                                // 22. y1 = y1 * tv2
    BigInt x2n = (tv3 * x1n) % p;                       // 23. x2n = tv3 * x1n
    BigInt y2 = (y1 * c2) % p;                          // 24. y2 = y1 * c2
    y2 = (y2 * tv1) % p;                                // 25. y2 = y2 * tv1
    y2 = (y2 * u) % p;                                  // 26. y2 = y2 * u
    tv2 = (y1 * y1) % p;                                // 27. tv2 = y1^2
    tv2 = (tv2 * gxd) % p;                              // 28. tv2 = tv2 * gxd
    final bool e2 = tv2 == gx1;                         // 29. e2 = tv2 == gx1
    BigInt xn = cmov(x2n, x1n, e2);                     // 30. xn = CMOV(x2n, x1n, e2)
    BigInt y = cmov(y2, y1, e2);                        // 31. y = CMOV(y2, y1, e2)
    final bool e3 = sgn(u) == sgn(y);                   // 32. e3 = sgn0(u) == sgn0(y)
    tv1 = (p - y) % p;
    y = cmov(tv1, y, e3);                               // 33. y = CMOV(-y, y, e3)
    BigInt x = xn * xd.modInverse(p) % p;               // 34. return (xn / xd, y)

    return _params.curve.createPoint(x, y);
  }

  /// Hash to scalar for key derivation.
  /// This matches @cloudflare/voprf-ts: expandXMD(msg, dst, L) mod order
  /// Note: This is different from _hashToField which mods by the field prime p.
  static BigInt hashToScalar(Uint8List input, Uint8List dst) {
    const int L = 48; // ceil((256 + 128) / 8) for P-256
    final bytes = _expandMessageXmd(input, dst, L);
    return _bytesToBigInt(bytes) % order;
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

  /// VOPRF version string - must match @cloudflare/voprf-ts
  static const String _voprfVersion = 'VOPRF08-';
  static const int _oprfMode = 0x00; // modeOPRF

  /// Build the context string according to VOPRF draft-08.
  /// Format: version || mode || 0x00 || suiteId
  /// This matches @cloudflare/voprf-ts: "VOPRF08-" + [mode, 0, id]
  Uint8List _buildContextString() {
    // For OPRF P256-SHA256 (id=3):
    // contextString = "VOPRF08-" + 0x00 + 0x00 + 0x03
    final suiteId = id.value; // 3 for P256-SHA256
    return Uint8List.fromList([
      ..._voprfVersion.codeUnits,
      _oprfMode,
      0x00,
      suiteId,
    ]);
  }

  /// Build the HashToGroup DST according to VOPRF draft-08.
  /// Format: "HashToGroup-" + contextString
  /// This matches @cloudflare/voprf-ts exactly.
  Uint8List _buildHashToGroupDST() {
    return joinAll([
      Uint8List.fromList('HashToGroup-'.codeUnits),
      _buildContextString(),
    ]);
  }

  /// Build the Finalize DST according to VOPRF draft-08.
  /// Format: "Finalize-" + contextString
  Uint8List _buildFinalizeDST() {
    return joinAll([
      Uint8List.fromList('Finalize-'.codeUnits),
      _buildContextString(),
    ]);
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
  /// Follows VOPRF draft-08 to match @cloudflare/voprf-ts:
  /// hashInput = len(input) || input || len(info) || info ||
  ///             len(element) || element || len(finalizeDST) || finalizeDST
  Uint8List finalize(Uint8List input, Uint8List blind, Uint8List evaluation) {
    // Deserialize blind and evaluation
    final r = P256Oprf.deserializeScalar(blind);
    final z = P256Oprf.deserializePoint(evaluation);

    // Unblind: Z / r = Z * r^(-1)
    final rInv = r.modInverse(P256Oprf.order);
    final n = P256Oprf.scalarMult(z, rInv);

    // Hash the result per VOPRF draft-08 (matching @cloudflare/voprf-ts)
    // Note: info is empty for OPAQUE (passed as empty Uint8Array in opaque-ts)
    final hash = Hash(P256Oprf.hashId);
    final encodedElement = P256Oprf.serializePoint(n);
    final emptyInfo = Uint8List(0);
    final finalizeDST = _buildFinalizeDST();

    return hash.sum(joinAll([
      encodeVector16(input),
      encodeVector16(emptyInfo),
      encodeVector16(encodedElement),
      encodeVector16(finalizeDST), // DST with length prefix per VOPRF draft-08
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
