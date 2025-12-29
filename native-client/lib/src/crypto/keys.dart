// Key management utilities using flutter_secure_storage.
// Provides secure storage for cryptographic keys on Android Keystore and iOS Keychain.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ml_kem.dart';
import 'ml_dsa.dart';

/// Storage keys for secure storage.
class _StorageKeys {
  static const String identityPublicKey = 'identity_public_key';
  static const String identitySecretKey = 'identity_secret_key';
  static const String transportPublicKey = 'transport_public_key';
  static const String transportSecretKey = 'transport_secret_key';
  static const String encryptionKey = 'encryption_key';
  static const String exportKey = 'export_key';
  static const String encryptionSalt = 'encryption_salt';
}

/// Complete key bundle for a user.
class KeyBundle {
  final IdentityKeyPair identityKeys;
  final TransportKeyPair transportKeys;
  final Uint8List encryptionKey;
  final Uint8List exportKey;

  KeyBundle({
    required this.identityKeys,
    required this.transportKeys,
    required this.encryptionKey,
    required this.exportKey,
  });
}

/// Manages cryptographic keys with secure storage.
///
/// Uses platform-native secure storage:
/// - Android: Android Keystore
/// - iOS: iOS Keychain
class KeyManager {
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  KeyManager._();

  // ============== Identity Keys (ML-DSA-65) ==============

  /// Store identity key pair.
  static Future<void> storeIdentityKeys(IdentityKeyPair keys) async {
    await _storage.write(
      key: _StorageKeys.identityPublicKey,
      value: base64Encode(keys.publicKey),
    );
    await _storage.write(
      key: _StorageKeys.identitySecretKey,
      value: base64Encode(keys.secretKey),
    );
  }

  /// Load identity key pair.
  /// Returns null if keys are not stored.
  static Future<IdentityKeyPair?> loadIdentityKeys() async {
    final publicKeyB64 = await _storage.read(key: _StorageKeys.identityPublicKey);
    final secretKeyB64 = await _storage.read(key: _StorageKeys.identitySecretKey);

    if (publicKeyB64 == null || secretKeyB64 == null) {
      return null;
    }

    return IdentityKeyPair(
      publicKey: base64Decode(publicKeyB64),
      secretKey: base64Decode(secretKeyB64),
    );
  }

  /// Check if identity keys are stored.
  static Future<bool> hasIdentityKeys() async {
    final publicKey = await _storage.read(key: _StorageKeys.identityPublicKey);
    return publicKey != null;
  }

  // ============== Transport Keys (ML-KEM-768) ==============

  /// Store transport key pair.
  static Future<void> storeTransportKeys(TransportKeyPair keys) async {
    await _storage.write(
      key: _StorageKeys.transportPublicKey,
      value: base64Encode(keys.publicKey),
    );
    await _storage.write(
      key: _StorageKeys.transportSecretKey,
      value: base64Encode(keys.secretKey),
    );
  }

  /// Load transport key pair.
  /// Returns null if keys are not stored.
  static Future<TransportKeyPair?> loadTransportKeys() async {
    final publicKeyB64 = await _storage.read(key: _StorageKeys.transportPublicKey);
    final secretKeyB64 = await _storage.read(key: _StorageKeys.transportSecretKey);

    if (publicKeyB64 == null || secretKeyB64 == null) {
      return null;
    }

    return TransportKeyPair(
      publicKey: base64Decode(publicKeyB64),
      secretKey: base64Decode(secretKeyB64),
    );
  }

  /// Check if transport keys are stored.
  static Future<bool> hasTransportKeys() async {
    final publicKey = await _storage.read(key: _StorageKeys.transportPublicKey);
    return publicKey != null;
  }

  // ============== Encryption Key (AES-256) ==============

  /// Store the local encryption key (for encrypting stored messages).
  static Future<void> storeEncryptionKey(Uint8List key) async {
    await _storage.write(
      key: _StorageKeys.encryptionKey,
      value: base64Encode(key),
    );
  }

  /// Load the local encryption key.
  static Future<Uint8List?> loadEncryptionKey() async {
    final keyB64 = await _storage.read(key: _StorageKeys.encryptionKey);
    if (keyB64 == null) {
      return null;
    }
    return base64Decode(keyB64);
  }

  /// Check if encryption key is stored.
  static Future<bool> hasEncryptionKey() async {
    final key = await _storage.read(key: _StorageKeys.encryptionKey);
    return key != null;
  }

  // ============== Export Key (from OPAQUE) ==============

  /// Store the OPAQUE export key.
  static Future<void> storeExportKey(Uint8List key) async {
    await _storage.write(
      key: _StorageKeys.exportKey,
      value: base64Encode(key),
    );
  }

  /// Load the OPAQUE export key.
  static Future<Uint8List?> loadExportKey() async {
    final keyB64 = await _storage.read(key: _StorageKeys.exportKey);
    if (keyB64 == null) {
      return null;
    }
    return base64Decode(keyB64);
  }

  // ============== Encryption Salt ==============

  /// Store the salt used for key derivation.
  static Future<void> storeEncryptionSalt(Uint8List salt) async {
    await _storage.write(
      key: _StorageKeys.encryptionSalt,
      value: base64Encode(salt),
    );
  }

  /// Load the encryption salt.
  static Future<Uint8List?> loadEncryptionSalt() async {
    final saltB64 = await _storage.read(key: _StorageKeys.encryptionSalt);
    if (saltB64 == null) {
      return null;
    }
    return base64Decode(saltB64);
  }

  // ============== Complete Key Bundle ==============

  /// Store a complete key bundle.
  static Future<void> storeKeyBundle(KeyBundle bundle) async {
    await storeIdentityKeys(bundle.identityKeys);
    await storeTransportKeys(bundle.transportKeys);
    await storeEncryptionKey(bundle.encryptionKey);
    await storeExportKey(bundle.exportKey);
  }

  /// Load a complete key bundle.
  /// Returns null if any keys are missing.
  static Future<KeyBundle?> loadKeyBundle() async {
    final identityKeys = await loadIdentityKeys();
    final transportKeys = await loadTransportKeys();
    final encryptionKey = await loadEncryptionKey();
    final exportKey = await loadExportKey();

    if (identityKeys == null ||
        transportKeys == null ||
        encryptionKey == null ||
        exportKey == null) {
      return null;
    }

    return KeyBundle(
      identityKeys: identityKeys,
      transportKeys: transportKeys,
      encryptionKey: encryptionKey,
      exportKey: exportKey,
    );
  }

  /// Check if a complete key bundle is stored.
  static Future<bool> hasKeyBundle() async {
    return await hasIdentityKeys() &&
        await hasTransportKeys() &&
        await hasEncryptionKey();
  }

  // ============== Key Rotation ==============

  /// Generate new transport keys (for key rotation).
  /// Returns the new key pair.
  static Future<TransportKeyPair> rotateTransportKeys() async {
    final newKeys = MlKem768.generateKeyPair();
    await storeTransportKeys(newKeys);
    return newKeys;
  }

  // ============== Clear Keys ==============

  /// Clear all stored keys.
  /// Use this on logout or account deletion.
  static Future<void> clearAllKeys() async {
    await _storage.delete(key: _StorageKeys.identityPublicKey);
    await _storage.delete(key: _StorageKeys.identitySecretKey);
    await _storage.delete(key: _StorageKeys.transportPublicKey);
    await _storage.delete(key: _StorageKeys.transportSecretKey);
    await _storage.delete(key: _StorageKeys.encryptionKey);
    await _storage.delete(key: _StorageKeys.exportKey);
    await _storage.delete(key: _StorageKeys.encryptionSalt);
  }

  // ============== Export/Import ==============

  /// Export public keys as JSON for sharing.
  /// Does NOT export secret keys.
  static Future<Map<String, String>?> exportPublicKeys() async {
    final identityKeys = await loadIdentityKeys();
    final transportKeys = await loadTransportKeys();

    if (identityKeys == null || transportKeys == null) {
      return null;
    }

    return {
      'identityPublicKey': base64Encode(identityKeys.publicKey),
      'transportPublicKey': base64Encode(transportKeys.publicKey),
    };
  }
}
