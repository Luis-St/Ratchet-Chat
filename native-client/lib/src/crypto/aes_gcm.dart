// AES-256-GCM encryption utilities.
// Uses pointycastle for symmetric encryption.

import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../opaque/crypto.dart';

/// AES-256-GCM encryption and decryption.
///
/// Uses 12-byte nonces (randomly generated) and produces
/// ciphertext with a 16-byte authentication tag appended.
class AesGcm {
  /// Key size in bytes (256 bits).
  static const int keyLength = 32;

  /// Nonce/IV size in bytes.
  static const int nonceLength = 12;

  /// Authentication tag size in bytes.
  static const int tagLength = 16;

  static final Prng _prng = Prng();

  AesGcm._();

  /// Encrypt plaintext using AES-256-GCM.
  ///
  /// [plaintext] - Data to encrypt.
  /// [key] - 32-byte encryption key.
  /// [aad] - Optional additional authenticated data.
  ///
  /// Returns: nonce (12 bytes) || ciphertext || tag (16 bytes)
  static Uint8List encrypt(Uint8List plaintext, Uint8List key, [Uint8List? aad]) {
    if (key.length != keyLength) {
      throw ArgumentError('Key must be $keyLength bytes, got ${key.length}');
    }

    // Generate random nonce
    final nonce = Uint8List.fromList(_prng.random(nonceLength));

    // Initialize GCM cipher
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(key),
      tagLength * 8, // Tag length in bits
      nonce,
      aad ?? Uint8List(0),
    );
    cipher.init(true, params);

    // Encrypt - getOutputSize returns max buffer size, actual size comes from processBytes + doFinal
    final outputBuffer = Uint8List(cipher.getOutputSize(plaintext.length));
    var len = cipher.processBytes(plaintext, 0, plaintext.length, outputBuffer, 0);
    len += cipher.doFinal(outputBuffer, len);

    // Only use the bytes actually written
    final ciphertext = outputBuffer.sublist(0, len);

    // Return nonce || ciphertext (includes tag)
    final result = Uint8List(nonceLength + ciphertext.length);
    result.setAll(0, nonce);
    result.setAll(nonceLength, ciphertext);
    return result;
  }

  /// Decrypt ciphertext using AES-256-GCM.
  ///
  /// [ciphertext] - nonce (12 bytes) || encrypted data || tag (16 bytes)
  /// [key] - 32-byte encryption key.
  /// [aad] - Optional additional authenticated data (must match encryption).
  ///
  /// Returns the decrypted plaintext.
  /// Throws [ArgumentError] if authentication fails.
  static Uint8List decrypt(Uint8List ciphertext, Uint8List key, [Uint8List? aad]) {
    if (key.length != keyLength) {
      throw ArgumentError('Key must be $keyLength bytes, got ${key.length}');
    }

    if (ciphertext.length < nonceLength + tagLength) {
      throw ArgumentError('Ciphertext too short');
    }

    // Extract nonce and encrypted data
    final nonce = ciphertext.sublist(0, nonceLength);
    final encryptedData = ciphertext.sublist(nonceLength);

    // Initialize GCM cipher for decryption
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(key),
      tagLength * 8,
      nonce,
      aad ?? Uint8List(0),
    );
    cipher.init(false, params);

    // Decrypt - GCM handles tag verification internally
    final outputBuffer = Uint8List(cipher.getOutputSize(encryptedData.length));

    try {
      var len = cipher.processBytes(encryptedData, 0, encryptedData.length, outputBuffer, 0);
      len += cipher.doFinal(outputBuffer, len);
      return outputBuffer.sublist(0, len);
    } catch (e) {
      throw ArgumentError('Authentication failed: invalid ciphertext or key');
    }
  }

  /// Derive an encryption key from a password using PBKDF2.
  ///
  /// [password] - User's password.
  /// [salt] - Random salt (should be stored with encrypted data).
  /// [iterations] - Number of iterations (default: 250,000).
  ///
  /// Returns a 32-byte encryption key.
  static Uint8List deriveKey(
    String password,
    Uint8List salt, {
    int iterations = 250000,
  }) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(salt, iterations, keyLength));

    final passwordBytes = Uint8List.fromList(password.codeUnits);
    return pbkdf2.process(passwordBytes);
  }

  /// Generate a random encryption key.
  static Uint8List generateKey() {
    return Uint8List.fromList(_prng.random(keyLength));
  }

  /// Generate a random salt for key derivation.
  static Uint8List generateSalt({int length = 16}) {
    return Uint8List.fromList(_prng.random(length));
  }
}
