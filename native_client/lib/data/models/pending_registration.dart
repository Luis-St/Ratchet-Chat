import 'package:flutter/foundation.dart';

import 'user_session.dart';

/// Holds all data needed during the registration TOTP setup phase.
///
/// After the user completes OPAQUE registration start, this stores the
/// pending data until they verify their TOTP setup.
@immutable
class PendingRegistration {
  const PendingRegistration({
    required this.username,
    required this.handle,
    required this.accountPassword,
    required this.kdfSalt,
    required this.kdfIterations,
    required this.masterKey,
    required this.opaqueFinish,
    required this.totpSecret,
    required this.totpUri,
    required this.encryptedIdentityKey,
    required this.encryptedTransportKey,
    required this.encryptedTotpSecret,
    required this.publicIdentityKey,
    required this.publicTransportKey,
  });

  /// The username being registered.
  final String username;

  /// The full handle (username@domain) returned from start.
  final String handle;

  /// The account password (for OPAQUE server authentication).
  /// Needed for auto-login after registration completes.
  final String accountPassword;

  /// Salt used for KDF (base64 encoded).
  final String kdfSalt;

  /// Number of iterations for KDF.
  final int kdfIterations;

  /// Derived master key (for encrypting keys).
  final Uint8List masterKey;

  /// OPAQUE registration finish message to send to server.
  final String opaqueFinish;

  /// TOTP secret (Base32 encoded) for authenticator app.
  final String totpSecret;

  /// otpauth:// URI for QR code scanning.
  final String totpUri;

  /// Encrypted identity private key.
  final EncryptedPayload encryptedIdentityKey;

  /// Encrypted transport private key.
  final EncryptedPayload encryptedTransportKey;

  /// Encrypted TOTP secret (for server storage).
  final EncryptedPayload encryptedTotpSecret;

  /// Public identity key (base64 encoded).
  final String publicIdentityKey;

  /// Public transport key (base64 encoded).
  final String publicTransportKey;

  @override
  String toString() =>
      'PendingRegistration(username: $username, handle: $handle)';
}
