// Auth state model for local database.

import 'dart:typed_data';

/// Represents the user's authentication state.
class AuthState {
  final int id; // Always 1 (singleton)
  final String? userId;
  final String? handle;
  final String? sessionToken;
  final Uint8List? identityPublicKey;
  final Uint8List? transportPublicKey;
  final String? passkeyCredentialId;
  final bool loggedIn;

  AuthState({
    this.id = 1,
    this.userId,
    this.handle,
    this.sessionToken,
    this.identityPublicKey,
    this.transportPublicKey,
    this.passkeyCredentialId,
    this.loggedIn = false,
  });

  /// Create from database row.
  factory AuthState.fromMap(Map<String, dynamic> map) {
    return AuthState(
      id: map['id'] as int,
      userId: map['user_id'] as String?,
      handle: map['handle'] as String?,
      sessionToken: map['session_token'] as String?,
      identityPublicKey: map['identity_public_key'] as Uint8List?,
      transportPublicKey: map['transport_public_key'] as Uint8List?,
      passkeyCredentialId: map['passkey_credential_id'] as String?,
      loggedIn: (map['logged_in'] as int?) == 1,
    );
  }

  /// Convert to database row.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'handle': handle,
      'session_token': sessionToken,
      'identity_public_key': identityPublicKey,
      'transport_public_key': transportPublicKey,
      'passkey_credential_id': passkeyCredentialId,
      'logged_in': loggedIn ? 1 : 0,
    };
  }

  /// Create a copy with updated fields.
  AuthState copyWith({
    String? userId,
    String? handle,
    String? sessionToken,
    Uint8List? identityPublicKey,
    Uint8List? transportPublicKey,
    String? passkeyCredentialId,
    bool? loggedIn,
  }) {
    return AuthState(
      id: id,
      userId: userId ?? this.userId,
      handle: handle ?? this.handle,
      sessionToken: sessionToken ?? this.sessionToken,
      identityPublicKey: identityPublicKey ?? this.identityPublicKey,
      transportPublicKey: transportPublicKey ?? this.transportPublicKey,
      passkeyCredentialId: passkeyCredentialId ?? this.passkeyCredentialId,
      loggedIn: loggedIn ?? this.loggedIn,
    );
  }

  /// Empty state for logged out users.
  static AuthState empty() => AuthState();
}
