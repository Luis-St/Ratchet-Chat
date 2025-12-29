// ML-KEM-768 Key Encapsulation Mechanism wrapper.
// Uses liboqs for NIST FIPS 203 compliant post-quantum key encapsulation.

import 'dart:typed_data';

import 'package:liboqs/liboqs.dart';

/// Key pair for transport encryption (ML-KEM-768).
class TransportKeyPair {
  final Uint8List publicKey;
  final Uint8List secretKey;

  TransportKeyPair({required this.publicKey, required this.secretKey});

  /// Create from raw bytes.
  factory TransportKeyPair.fromBytes({
    required Uint8List publicKey,
    required Uint8List secretKey,
  }) {
    return TransportKeyPair(publicKey: publicKey, secretKey: secretKey);
  }
}

/// Result of key encapsulation.
class EncapsulationResult {
  /// Ciphertext to send to recipient.
  final Uint8List ciphertext;

  /// Shared secret for encryption (use with AES-GCM).
  final Uint8List sharedSecret;

  EncapsulationResult({required this.ciphertext, required this.sharedSecret});
}

/// ML-KEM-768 wrapper for transport encryption.
///
/// ML-KEM-768 (Module-Lattice Key Encapsulation Mechanism) is a
/// post-quantum key encapsulation mechanism standardized by NIST
/// in FIPS 203. It provides 192-bit security against quantum attacks.
class MlKem768 {
  static const String _algorithmName = 'ML-KEM-768';

  /// Public key size in bytes.
  static const int publicKeyLength = 1184;

  /// Secret key size in bytes.
  static const int secretKeyLength = 2400;

  /// Ciphertext size in bytes.
  static const int ciphertextLength = 1088;

  /// Shared secret size in bytes.
  static const int sharedSecretLength = 32;

  MlKem768._();

  /// Generate a new transport key pair.
  static TransportKeyPair generateKeyPair() {
    final kem = KEM.create(_algorithmName);

    try {
      final keyPair = kem.generateKeyPair();
      return TransportKeyPair(
        publicKey: Uint8List.fromList(keyPair.publicKey),
        secretKey: Uint8List.fromList(keyPair.secretKey),
      );
    } finally {
      kem.dispose();
    }
  }

  /// Encapsulate a shared secret using the recipient's public key.
  ///
  /// Returns an [EncapsulationResult] containing:
  /// - [ciphertext]: Send this to the recipient
  /// - [sharedSecret]: Use this for symmetric encryption (AES-GCM)
  static EncapsulationResult encapsulate(Uint8List publicKey) {
    if (publicKey.length != publicKeyLength) {
      throw ArgumentError(
        'Invalid public key length: ${publicKey.length}, expected $publicKeyLength',
      );
    }

    final kem = KEM.create(_algorithmName);

    try {
      final result = kem.encapsulate(publicKey);
      return EncapsulationResult(
        ciphertext: Uint8List.fromList(result.ciphertext),
        sharedSecret: Uint8List.fromList(result.sharedSecret),
      );
    } finally {
      kem.dispose();
    }
  }

  /// Decapsulate a shared secret using the recipient's secret key.
  ///
  /// Returns the shared secret that matches what the sender derived.
  static Uint8List decapsulate(Uint8List ciphertext, Uint8List secretKey) {
    if (ciphertext.length != ciphertextLength) {
      throw ArgumentError(
        'Invalid ciphertext length: ${ciphertext.length}, expected $ciphertextLength',
      );
    }
    if (secretKey.length != secretKeyLength) {
      throw ArgumentError(
        'Invalid secret key length: ${secretKey.length}, expected $secretKeyLength',
      );
    }

    final kem = KEM.create(_algorithmName);

    try {
      final sharedSecret = kem.decapsulate(ciphertext, secretKey);
      return Uint8List.fromList(sharedSecret);
    } finally {
      kem.dispose();
    }
  }
}
