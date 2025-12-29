// Auth Data Access Object.

import 'dart:typed_data';

import '../database.dart';
import '../models/auth_state.dart';

/// Data access object for authentication state.
class AuthDao {
  final AppDatabase _appDb;

  AuthDao([AppDatabase? db]) : _appDb = db ?? AppDatabase();

  /// Get the current auth state.
  Future<AuthState> getAuthState() async {
    final db = await _appDb.database;
    final results = await db.query('auth', where: 'id = 1');

    if (results.isEmpty) {
      return AuthState.empty();
    }

    return AuthState.fromMap(results.first);
  }

  /// Update auth state.
  Future<void> updateAuthState(AuthState state) async {
    final db = await _appDb.database;
    await db.update(
      'auth',
      state.toMap(),
      where: 'id = 1',
    );
  }

  /// Set logged in state with user info.
  Future<void> login({
    required String userId,
    required String handle,
    required String sessionToken,
    required Uint8List identityPublicKey,
    required Uint8List transportPublicKey,
    String? passkeyCredentialId,
  }) async {
    final state = AuthState(
      userId: userId,
      handle: handle,
      sessionToken: sessionToken,
      identityPublicKey: identityPublicKey,
      transportPublicKey: transportPublicKey,
      passkeyCredentialId: passkeyCredentialId,
      loggedIn: true,
    );
    await updateAuthState(state);
  }

  /// Clear auth state (logout).
  Future<void> logout() async {
    await updateAuthState(AuthState.empty());
  }

  /// Update session token.
  Future<void> updateSessionToken(String token) async {
    final db = await _appDb.database;
    await db.update(
      'auth',
      {'session_token': token},
      where: 'id = 1',
    );
  }

  /// Update passkey credential ID.
  Future<void> updatePasskeyCredentialId(String credentialId) async {
    final db = await _appDb.database;
    await db.update(
      'auth',
      {'passkey_credential_id': credentialId},
      where: 'id = 1',
    );
  }

  /// Check if user is logged in.
  Future<bool> isLoggedIn() async {
    final state = await getAuthState();
    return state.loggedIn;
  }
}
