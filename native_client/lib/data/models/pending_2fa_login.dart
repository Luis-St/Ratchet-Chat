import 'package:flutter/foundation.dart';

/// Holds state for a pending 2FA login flow.
///
/// After successful OPAQUE password verification, the server returns a
/// session ticket that must be used to verify the TOTP code. This model
/// stores all the information needed to complete the 2FA flow.
@immutable
class Pending2faLogin {
  const Pending2faLogin({
    required this.username,
    required this.handle,
    required this.sessionTicket,
    required this.kdfSalt,
    required this.kdfIterations,
    required this.expiresAt,
  });

  /// The username being logged in.
  final String username;

  /// The full handle (username@host).
  final String handle;

  /// The session ticket from the server for 2FA verification.
  final String sessionTicket;

  /// KDF salt for deriving the master key.
  final String kdfSalt;

  /// KDF iterations for deriving the master key.
  final int kdfIterations;

  /// When this session ticket expires.
  final DateTime expiresAt;

  /// Whether this session ticket has expired.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pending2faLogin &&
          runtimeType == other.runtimeType &&
          username == other.username &&
          handle == other.handle &&
          sessionTicket == other.sessionTicket &&
          kdfSalt == other.kdfSalt &&
          kdfIterations == other.kdfIterations &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(
        username,
        handle,
        sessionTicket,
        kdfSalt,
        kdfIterations,
        expiresAt,
      );

  @override
  String toString() =>
      'Pending2faLogin(username: $username, handle: $handle, expiresAt: $expiresAt)';
}
