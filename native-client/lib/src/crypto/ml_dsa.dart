// ML-DSA-65 Digital Signature wrapper.
// Uses liboqs for NIST FIPS 204 compliant post-quantum digital signatures.

import 'dart:typed_data';

import 'package:liboqs/liboqs.dart';

/// Key pair for identity/signing (ML-DSA-65).
class IdentityKeyPair {
  final Uint8List publicKey;
  final Uint8List secretKey;

  IdentityKeyPair({required this.publicKey, required this.secretKey});

  /// Create from raw bytes.
  factory IdentityKeyPair.fromBytes({
    required Uint8List publicKey,
    required Uint8List secretKey,
  }) {
    return IdentityKeyPair(publicKey: publicKey, secretKey: secretKey);
  }
}

/// ML-DSA-65 wrapper for digital signatures.
///
/// ML-DSA-65 (Module-Lattice Digital Signature Algorithm) is a
/// post-quantum digital signature scheme standardized by NIST
/// in FIPS 204. It provides 192-bit security against quantum attacks.
class MlDsa65 {
  static const String _algorithmName = 'ML-DSA-65';

  /// Public key size in bytes.
  static const int publicKeyLength = 1952;

  /// Secret key size in bytes.
  static const int secretKeyLength = 4032;

  /// Maximum signature size in bytes.
  static const int maxSignatureLength = 3309;

  MlDsa65._();

  /// Generate a new identity key pair.
  static IdentityKeyPair generateKeyPair() {
    final sig = Signature.create(_algorithmName);

    try {
      final keyPair = sig.generateKeyPair();
      return IdentityKeyPair(
        publicKey: Uint8List.fromList(keyPair.publicKey),
        secretKey: Uint8List.fromList(keyPair.secretKey),
      );
    } finally {
      sig.dispose();
    }
  }

  /// Sign a message using the secret key.
  ///
  /// Returns the digital signature.
  static Uint8List sign(Uint8List message, Uint8List secretKey) {
    if (secretKey.length != secretKeyLength) {
      throw ArgumentError(
        'Invalid secret key length: ${secretKey.length}, expected $secretKeyLength',
      );
    }

    final sig = Signature.create(_algorithmName);

    try {
      final signature = sig.sign(message, secretKey);
      return Uint8List.fromList(signature);
    } finally {
      sig.dispose();
    }
  }

  /// Verify a signature using the public key.
  ///
  /// Returns true if the signature is valid, false otherwise.
  static bool verify(
    Uint8List message,
    Uint8List signature,
    Uint8List publicKey,
  ) {
    if (publicKey.length != publicKeyLength) {
      throw ArgumentError(
        'Invalid public key length: ${publicKey.length}, expected $publicKeyLength',
      );
    }

    final sig = Signature.create(_algorithmName);

    try {
      return sig.verify(message, signature, publicKey);
    } finally {
      sig.dispose();
    }
  }
}
