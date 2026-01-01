import 'package:flutter/foundation.dart';

/// Encrypted key payload with ciphertext and IV.
@immutable
class EncryptedPayload {
  const EncryptedPayload({required this.ciphertext, required this.iv});

  final String ciphertext;
  final String iv;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EncryptedPayload &&
          runtimeType == other.runtimeType &&
          ciphertext == other.ciphertext &&
          iv == other.iv;

  @override
  int get hashCode => Object.hash(ciphertext, iv);
}

/// User session data including token and keys.
@immutable
class UserSession {
  const UserSession({
    required this.token,
    required this.userId,
    required this.username,
    required this.handle,
    required this.kdfSalt,
    required this.kdfIterations,
    required this.encryptedIdentityKey,
    required this.encryptedTransportKey,
    required this.publicIdentityKey,
    required this.publicTransportKey,
  });

  /// JWT authentication token.
  final String token;

  /// User's unique identifier.
  final String userId;

  /// User's username (without domain).
  final String username;

  /// User's full handle (username@domain).
  final String handle;

  /// Salt used for KDF (key derivation function).
  final String kdfSalt;

  /// Number of iterations for KDF.
  final int kdfIterations;

  /// Encrypted identity private key.
  final EncryptedPayload encryptedIdentityKey;

  /// Encrypted transport private key.
  final EncryptedPayload encryptedTransportKey;

  /// Public identity key (base64 encoded).
  final String publicIdentityKey;

  /// Public transport key (base64 encoded).
  final String publicTransportKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSession &&
          runtimeType == other.runtimeType &&
          token == other.token &&
          userId == other.userId &&
          username == other.username;

  @override
  int get hashCode => Object.hash(token, userId, username);

  @override
  String toString() =>
      'UserSession(userId: $userId, username: $username, handle: $handle)';
}

/// Decrypted keys available after unlocking.
@immutable
class DecryptedKeys {
  const DecryptedKeys({
    required this.identityPrivateKey,
    required this.transportPrivateKey,
  });

  final Uint8List identityPrivateKey;
  final Uint8List transportPrivateKey;
}
