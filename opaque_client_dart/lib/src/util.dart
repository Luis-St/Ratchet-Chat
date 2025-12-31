// Copyright (c) 2021 Cloudflare, Inc. and contributors.
// Ported to Dart for Ratchet-Chat Flutter client.
// Licensed under the BSD-3-Clause license.

import 'dart:typed_data';

/// Concatenate multiple byte arrays into one.
Uint8List joinAll(List<Uint8List> arrays) {
  int size = 0;
  for (final arr in arrays) {
    size += arr.length;
  }
  final result = Uint8List(size);
  int offset = 0;
  for (final arr in arrays) {
    result.setAll(offset, arr);
    offset += arr.length;
  }
  return result;
}

/// Encode a number as big-endian bytes.
Uint8List encodeNumber(int n, int bits) {
  if (bits <= 0 || bits > 32) {
    throw ArgumentError('only supports 32-bit encoding');
  }
  final max = 1 << bits;
  if (n < 0 || n >= max) {
    throw ArgumentError('number out of range [0, 2^$bits - 1]');
  }
  final numBytes = (bits + 7) ~/ 8;
  final out = Uint8List(numBytes);
  for (int i = 0; i < numBytes; i++) {
    out[numBytes - 1 - i] = (n >> (8 * i)) & 0xff;
  }
  return out;
}

/// Decode big-endian bytes to a number.
int decodeNumber(Uint8List a, int bits) {
  if (bits <= 0 || bits > 32) {
    throw ArgumentError('only supports 32-bit encoding');
  }
  final numBytes = (bits + 7) ~/ 8;
  if (a.length != numBytes) {
    throw ArgumentError('array has wrong size');
  }
  int out = 0;
  for (int i = 0; i < a.length; i++) {
    out = (out << 8) + a[i];
  }
  return out;
}

/// Encode a byte array with a length prefix.
Uint8List _encodeVector(Uint8List a, int bitsHeader) {
  return joinAll([encodeNumber(a.length, bitsHeader), a]);
}

/// Decode a length-prefixed byte array.
({Uint8List payload, int consumed}) _decodeVector(Uint8List a, int bitsHeader) {
  if (a.isEmpty) {
    throw ArgumentError('empty vector not allowed');
  }
  final numBytes = (bitsHeader + 7) ~/ 8;
  final header = a.sublist(0, numBytes);
  final len = decodeNumber(header, bitsHeader);
  final consumed = numBytes + len;
  final payload = a.sublist(numBytes, consumed);
  return (payload: payload, consumed: consumed);
}

/// Encode with 8-bit length prefix.
Uint8List encodeVector8(Uint8List a) => _encodeVector(a, 8);

/// Encode with 16-bit length prefix.
Uint8List encodeVector16(Uint8List a) => _encodeVector(a, 16);

/// Decode with 16-bit length prefix.
({Uint8List payload, int consumed}) decodeVector16(Uint8List a) =>
    _decodeVector(a, 16);

/// Check and return a vector of exact length.
Uint8List checkedVector(Uint8List a, int n, [String name = 'array']) {
  if (a.length < n) {
    throw ArgumentError('$name has wrong length: expected $n, got ${a.length}');
  }
  return a.sublist(0, n);
}

/// XOR two byte arrays of the same length.
Uint8List xor(Uint8List a, Uint8List b) {
  if (a.length != b.length || a.isEmpty) {
    throw ArgumentError('arrays of different length');
  }
  final c = Uint8List(a.length);
  for (int i = 0; i < a.length; i++) {
    c[i] = a[i] ^ b[i];
  }
  return c;
}

/// Constant-time equality check.
bool ctEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length || a.isEmpty) {
    return false;
  }
  int c = 0;
  for (int i = 0; i < a.length; i++) {
    c |= a[i] ^ b[i];
  }
  return c == 0;
}

/// Convert a string to UTF-8 bytes.
Uint8List encodeString(String s) {
  return Uint8List.fromList(s.codeUnits);
}
