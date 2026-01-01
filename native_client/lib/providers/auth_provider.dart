import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/auth_exceptions.dart';
import '../data/models/auth_state.dart';
import '../data/models/user_session.dart';
import '../data/repositories/auth_repository.dart';
import '../data/services/api_service.dart';
import '../data/services/crypto_service.dart';
import 'service_providers.dart';

/// Notifier for managing authentication state.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authRepository, this._apiService, this._cryptoService)
    : super(const AuthState.loading()) {
    _init();
  }

  final AuthRepository _authRepository;
  final ApiService _apiService;
  final CryptoService _cryptoService;

  UserSession? _session;
  DecryptedKeys? _decryptedKeys;

  /// Gets the current session.
  UserSession? get session => _session;

  /// Gets the decrypted keys (only available when authenticated).
  DecryptedKeys? get decryptedKeys => _decryptedKeys;

  Future<void> _init() async {
    try {
      // Check for existing session
      final session = await _authRepository.getSession();
      if (session == null) {
        state = const AuthState.guest();
        return;
      }

      _session = session;
      _apiService.setToken(session.token);

      // Check for saved master key
      final masterKey = await _authRepository.getMasterKey();
      if (masterKey != null) {
        // Try to decrypt keys
        try {
          final identityKey = _cryptoService.decrypt(
            session.encryptedIdentityKey,
            masterKey,
          );
          final transportKey = _cryptoService.decrypt(
            session.encryptedTransportKey,
            masterKey,
          );

          _decryptedKeys = DecryptedKeys(
            identityPrivateKey: identityKey,
            transportPrivateKey: transportKey,
          );

          state = AuthState.authenticated(
            userId: session.userId,
            username: session.username,
            handle: session.handle,
          );
        } catch (e) {
          // Master key invalid, need to unlock
          state = AuthState.locked(
            userId: session.userId,
            username: session.username,
            handle: session.handle,
          );
        }
      } else {
        // No master key saved, need to unlock
        state = AuthState.locked(
          userId: session.userId,
          username: session.username,
          handle: session.handle,
        );
      }
    } catch (e) {
      state = AuthState.guest(error: e.toString());
    }
  }

  /// Logs in with username and password.
  Future<void> login({
    required String username,
    required String password,
    required bool savePassword,
  }) async {
    state = const AuthState.loading();

    try {
      final session = await _authRepository.login(
        username: username,
        password: password,
        savePassword: savePassword,
      );

      _session = session;

      // Derive master key and decrypt keys
      final masterKey = _cryptoService.deriveMasterKey(
        password: password,
        saltBase64: session.kdfSalt,
        iterations: session.kdfIterations,
      );

      final identityKey = _cryptoService.decrypt(
        session.encryptedIdentityKey,
        masterKey,
      );
      final transportKey = _cryptoService.decrypt(
        session.encryptedTransportKey,
        masterKey,
      );

      _decryptedKeys = DecryptedKeys(
        identityPrivateKey: identityKey,
        transportPrivateKey: transportKey,
      );

      state = AuthState.authenticated(
        userId: session.userId,
        username: session.username,
        handle: session.handle,
      );
    } on AuthException catch (e) {
      state = AuthState.guest(error: e.message);
    } catch (e) {
      state = AuthState.guest(error: 'Login failed: ${e.toString()}');
    }
  }

  /// Unlocks the session with the password.
  Future<void> unlock(String password) async {
    if (_session == null) {
      state = const AuthState.guest(error: 'No session to unlock');
      return;
    }

    state = const AuthState.loading();

    try {
      final decryptedKeys = await _authRepository.unlock(
        password: password,
        session: _session!,
      );

      _decryptedKeys = decryptedKeys;

      state = AuthState.authenticated(
        userId: _session!.userId,
        username: _session!.username,
        handle: _session!.handle,
      );
    } on DecryptionException catch (e) {
      state = AuthState.locked(
        userId: _session!.userId,
        username: _session!.username,
        handle: _session!.handle,
      ).copyWith(error: e.message);
    } catch (e) {
      state = AuthState.locked(
        userId: _session!.userId,
        username: _session!.username,
        handle: _session!.handle,
      ).copyWith(error: 'Unlock failed: ${e.toString()}');
    }
  }

  /// Registers a new user.
  Future<void> register({
    required String username,
    required String password,
    required bool savePassword,
  }) async {
    state = const AuthState.loading();

    try {
      final session = await _authRepository.register(
        username: username,
        password: password,
        savePassword: savePassword,
      );

      _session = session;

      // Derive master key and decrypt keys
      final masterKey = _cryptoService.deriveMasterKey(
        password: password,
        saltBase64: session.kdfSalt,
        iterations: session.kdfIterations,
      );

      final identityKey = _cryptoService.decrypt(
        session.encryptedIdentityKey,
        masterKey,
      );
      final transportKey = _cryptoService.decrypt(
        session.encryptedTransportKey,
        masterKey,
      );

      _decryptedKeys = DecryptedKeys(
        identityPrivateKey: identityKey,
        transportPrivateKey: transportKey,
      );

      state = AuthState.authenticated(
        userId: session.userId,
        username: session.username,
        handle: session.handle,
      );
    } on AuthException catch (e) {
      state = AuthState.guest(error: e.message);
    } catch (e) {
      state = AuthState.guest(error: 'Registration failed: ${e.toString()}');
    }
  }

  /// Logs out and clears the session.
  Future<void> logout() async {
    await _authRepository.logout();
    _session = null;
    _decryptedKeys = null;
    state = const AuthState.guest();
  }

  /// Clears any error.
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for authentication state.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(apiServiceProvider),
    ref.watch(cryptoServiceProvider),
  );
});
