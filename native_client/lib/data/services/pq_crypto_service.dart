import 'dart:typed_data';

import 'package:oqs/oqs.dart';

/// Key pair for identity (ML-DSA-65 digital signatures).
class IdentityKeyPair {
  const IdentityKeyPair({
    required this.publicKey,
    required this.secretKey,
  });

  /// Public key (1952 bytes for ML-DSA-65).
  final Uint8List publicKey;

  /// Secret key (4032 bytes for ML-DSA-65).
  final Uint8List secretKey;
}

/// Key pair for transport (ML-KEM-768 key encapsulation).
class TransportKeyPair {
  const TransportKeyPair({
    required this.publicKey,
    required this.secretKey,
  });

  /// Public key (1184 bytes for ML-KEM-768).
  final Uint8List publicKey;

  /// Secret key (2400 bytes for ML-KEM-768).
  final Uint8List secretKey;
}

/// Service for post-quantum cryptographic operations.
///
/// Uses ML-DSA-65 (FIPS 204) for digital signatures and
/// ML-KEM-768 (FIPS 203) for key encapsulation.
///
/// IMPORTANT: Call [initialize] once at app startup before using any methods.
class PqCryptoService {
  static bool _initialized = false;

  /// Initializes the liboqs library.
  ///
  /// Must be called once at app startup before using any PQ crypto methods.
  /// Safe to call multiple times (subsequent calls are no-ops).
  static void initialize() {
    if (_initialized) return;
    LibOQS.init();
    _initialized = true;
  }

  /// Generates a new identity key pair using ML-DSA-65.
  ///
  /// ML-DSA-65 provides 192-bit classical / 128-bit quantum security.
  /// - Public key: 1952 bytes
  /// - Secret key: 4032 bytes
  IdentityKeyPair generateIdentityKeyPair() {
    _ensureInitialized();

    final sig = Signature.create('ML-DSA-65');
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

  /// Generates a new transport key pair using ML-KEM-768.
  ///
  /// ML-KEM-768 provides 192-bit classical / 128-bit quantum security.
  /// - Public key: 1184 bytes
  /// - Secret key: 2400 bytes
  TransportKeyPair generateTransportKeyPair() {
    _ensureInitialized();

    final kem = KEM.create('ML-KEM-768');
    if (kem == null) {
      throw StateError('Failed to create ML-KEM-768 instance');
    }
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

  /// Signs a message using ML-DSA-65.
  Uint8List sign(Uint8List message, Uint8List secretKey) {
    _ensureInitialized();

    final sig = Signature.create('ML-DSA-65');
    try {
      return Uint8List.fromList(sig.sign(message, secretKey));
    } finally {
      sig.dispose();
    }
  }

  /// Verifies a signature using ML-DSA-65.
  bool verify(Uint8List message, Uint8List signature, Uint8List publicKey) {
    _ensureInitialized();

    final sig = Signature.create('ML-DSA-65');
    try {
      return sig.verify(message, signature, publicKey);
    } finally {
      sig.dispose();
    }
  }

  /// Encapsulates a shared secret using ML-KEM-768.
  ///
  /// Returns the ciphertext and shared secret.
  ({Uint8List ciphertext, Uint8List sharedSecret}) encapsulate(
      Uint8List publicKey) {
    _ensureInitialized();

    final kem = KEM.create('ML-KEM-768');
    if (kem == null) {
      throw StateError('Failed to create ML-KEM-768 instance');
    }
    try {
      final result = kem.encapsulate(publicKey);
      return (
        ciphertext: Uint8List.fromList(result.ciphertext),
        sharedSecret: Uint8List.fromList(result.sharedSecret),
      );
    } finally {
      kem.dispose();
    }
  }

  /// Decapsulates a shared secret using ML-KEM-768.
  Uint8List decapsulate(Uint8List ciphertext, Uint8List secretKey) {
    _ensureInitialized();

    final kem = KEM.create('ML-KEM-768');
    if (kem == null) {
      throw StateError('Failed to create ML-KEM-768 instance');
    }
    try {
      return Uint8List.fromList(kem.decapsulate(ciphertext, secretKey));
    } finally {
      kem.dispose();
    }
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'PqCryptoService not initialized. Call PqCryptoService.initialize() '
        'at app startup.',
      );
    }
  }
}
