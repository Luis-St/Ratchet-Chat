import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/auth_exceptions.dart';
import '../data/models/auth_state.dart';
import '../data/models/pending_2fa_login.dart';
import '../data/models/pending_registration.dart';
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
  bool _loggedInWithPasskey = false;

  // Password + 2FA login state
  Pending2faLogin? _pending2faLogin;
  bool _pendingSavePassword = false;
  int? _remainingRecoveryCodes;

  // Password + 2FA registration state
  PendingRegistration? _pendingRegistration;
  List<String>? _recoveryCodes;

  /// Gets the current session.
  UserSession? get session => _session;

  /// Gets the decrypted keys (only available when authenticated).
  DecryptedKeys? get decryptedKeys => _decryptedKeys;

  /// Whether passkeys are supported on this platform.
  bool get isPasskeySupported => _authRepository.isPasskeySupported;

  /// Gets the pending 2FA login info.
  Pending2faLogin? get pending2faLogin => _pending2faLogin;

  /// Gets the remaining recovery codes count (after recovery code login).
  int? get remainingRecoveryCodes => _remainingRecoveryCodes;

  /// Gets the pending registration info for TOTP setup.
  PendingRegistration? get pendingRegistration => _pendingRegistration;

  /// Gets the recovery codes (after registration completion).
  List<String>? get recoveryCodes => _recoveryCodes;

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

  /// Logs in with username and password (with 2FA support).
  ///
  /// If 2FA is required, transitions to [AuthStatus.awaiting2fa].
  /// If no 2FA, transitions to [AuthStatus.awaitingMasterPassword].
  Future<void> login({
    required String username,
    required String password,
    required bool savePassword,
  }) async {
    state = const AuthState.loading();

    try {
      final result = await _authRepository.loginWithPassword(
        username: username,
        password: password,
      );

      _pendingSavePassword = savePassword;

      if (result.pending2fa != null) {
        // 2FA required - store pending login and transition to 2FA state
        _pending2faLogin = result.pending2fa;
        state = AuthState.awaiting2fa(
          username: result.pending2fa!.username,
          handle: result.pending2fa!.handle,
        );
      } else if (result.session != null) {
        // No 2FA - go directly to master password unlock
        _session = result.session;
        state = AuthState.awaitingMasterPassword(
          username: result.session!.username,
          handle: result.session!.handle,
        );
      }
    } on AuthException catch (e) {
      _clearPendingLogin();
      state = AuthState.guest(error: e.message);
    } catch (e) {
      _clearPendingLogin();
      state = AuthState.guest(error: 'Login failed: ${e.toString()}');
    }
  }

  /// Verifies a TOTP code during password + 2FA login.
  Future<void> verifyTotp(String totpCode) async {
    if (_pending2faLogin == null) {
      state = const AuthState.guest(error: 'No pending 2FA login');
      return;
    }

    state = const AuthState.loading();

    try {
      final session = await _authRepository.verifyTotp(
        pendingLogin: _pending2faLogin!,
        totpCode: totpCode,
      );

      _session = session;
      _pending2faLogin = null;

      state = AuthState.awaitingMasterPassword(
        username: session.username,
        handle: session.handle,
      );
    } on AuthException catch (e) {
      state = AuthState.awaiting2fa(
        username: _pending2faLogin!.username,
        handle: _pending2faLogin!.handle,
      ).copyWith(error: e.message);
    } catch (e) {
      state = AuthState.awaiting2fa(
        username: _pending2faLogin!.username,
        handle: _pending2faLogin!.handle,
      ).copyWith(error: 'Verification failed: ${e.toString()}');
    }
  }

  /// Verifies a recovery code during password + 2FA login.
  Future<void> verifyRecoveryCode(String recoveryCode) async {
    if (_pending2faLogin == null) {
      state = const AuthState.guest(error: 'No pending 2FA login');
      return;
    }

    state = const AuthState.loading();

    try {
      final result = await _authRepository.verifyRecoveryCode(
        pendingLogin: _pending2faLogin!,
        recoveryCode: recoveryCode,
      );

      _session = result.session;
      _remainingRecoveryCodes = result.remainingCodes;
      _pending2faLogin = null;

      state = AuthState.awaitingMasterPassword(
        username: result.session.username,
        handle: result.session.handle,
      );
    } on AuthException catch (e) {
      state = AuthState.awaiting2fa(
        username: _pending2faLogin!.username,
        handle: _pending2faLogin!.handle,
      ).copyWith(error: e.message);
    } catch (e) {
      state = AuthState.awaiting2fa(
        username: _pending2faLogin!.username,
        handle: _pending2faLogin!.handle,
      ).copyWith(error: 'Verification failed: ${e.toString()}');
    }
  }

  /// Unlocks with master password after 2FA verification (or no 2FA).
  ///
  /// Derives the master key, decrypts the private keys, and saves the session.
  Future<void> unlockWithMasterPassword(String password) async {
    if (_session == null) {
      state = const AuthState.guest(error: 'No session to unlock');
      return;
    }

    state = const AuthState.loading();

    try {
      // Derive master key
      final masterKey = _cryptoService.deriveMasterKey(
        password: password,
        saltBase64: _session!.kdfSalt,
        iterations: _session!.kdfIterations,
      );

      // Decrypt private keys
      final identityKey = _cryptoService.decrypt(
        _session!.encryptedIdentityKey,
        masterKey,
      );
      final transportKey = _cryptoService.decrypt(
        _session!.encryptedTransportKey,
        masterKey,
      );

      _decryptedKeys = DecryptedKeys(
        identityPrivateKey: identityKey,
        transportPrivateKey: transportKey,
      );

      // Save session
      await _authRepository.saveSession(
        session: _session!,
        masterKey: masterKey,
        savePassword: _pendingSavePassword,
      );

      // Clear pending state
      _pendingSavePassword = false;

      state = AuthState.authenticated(
        userId: _session!.userId,
        username: _session!.username,
        handle: _session!.handle,
      );
    } on DecryptionException catch (e) {
      state = AuthState.awaitingMasterPassword(
        username: _session!.username,
        handle: _session!.handle,
      ).copyWith(error: e.message);
    } catch (e) {
      state = AuthState.awaitingMasterPassword(
        username: _session!.username,
        handle: _session!.handle,
      ).copyWith(error: 'Unlock failed: ${e.toString()}');
    }
  }

  /// Cancels the current password login flow.
  void cancelPasswordLogin() {
    _clearPendingLogin();
    state = const AuthState.guest();
  }

  /// Clears all pending login state.
  void _clearPendingLogin() {
    _pending2faLogin = null;
    _pendingSavePassword = false;
    _remainingRecoveryCodes = null;
    _session = null;
  }

  /// Clears all pending registration state.
  void _clearPendingRegistration() {
    _pendingRegistration = null;
    _recoveryCodes = null;
    _pendingSavePassword = false;
  }

  /// Unlocks the session with the password.
  ///
  /// If the user logged in with passkey, this will verify the password
  /// using OPAQUE unlock endpoints. Otherwise, it will just decrypt
  /// the keys locally.
  Future<void> unlock(String password, {bool savePassword = false}) async {
    if (_session == null) {
      state = const AuthState.guest(error: 'No session to unlock');
      return;
    }

    state = const AuthState.loading();

    try {
      DecryptedKeys decryptedKeys;

      if (_loggedInWithPasskey) {
        // User logged in with passkey, verify password via OPAQUE
        decryptedKeys = await _authRepository.unlockWithOpaqueVerification(
          password: password,
          session: _session!,
          savePassword: savePassword,
        );
      } else {
        // Regular unlock, just decrypt keys locally
        decryptedKeys = await _authRepository.unlock(
          password: password,
          session: _session!,
        );
      }

      _decryptedKeys = decryptedKeys;
      _loggedInWithPasskey = false; // Reset flag

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
    } on InvalidCredentialsException catch (e) {
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

  /// Logs in using passkey only.
  ///
  /// After successful passkey login, the user will be in a "locked" state
  /// and must enter their password to decrypt the private keys.
  Future<void> loginWithPasskey() async {
    state = const AuthState.loading();

    try {
      final session = await _authRepository.loginWithPasskey();

      _session = session;
      _loggedInWithPasskey = true;

      state = AuthState.locked(
        userId: session.userId,
        username: session.username,
        handle: session.handle,
      );
    } on AuthException catch (e) {
      state = AuthState.guest(error: e.message);
    } catch (e) {
      state = AuthState.guest(error: 'Passkey login failed: ${e.toString()}');
    }
  }

  /// Registers a new user with passkey.
  ///
  /// This creates a passkey credential along with OPAQUE password authentication.
  Future<void> registerWithPasskey({
    required String username,
    required String password,
    required bool savePassword,
  }) async {
    state = const AuthState.loading();

    try {
      final session = await _authRepository.registerWithPasskey(
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

  // ============== PASSWORD + 2FA REGISTRATION METHODS ==============

  /// Registers a new user with password and 2FA (TOTP).
  ///
  /// This follows the web client's two-password design:
  /// - [accountPassword]: Used for OPAQUE server authentication
  /// - [masterPassword]: Used for deriving the master key (local encryption)
  ///
  /// This starts the registration flow by generating keys and TOTP secret,
  /// then transitions to [AuthStatus.awaitingTotpSetup] for the user to
  /// verify their authenticator app.
  Future<void> registerWithPassword({
    required String username,
    required String accountPassword,
    required String masterPassword,
    required bool savePassword,
  }) async {
    state = const AuthState.loading();

    try {
      _pendingSavePassword = savePassword;

      final pending = await _authRepository.registerWithPasswordStart(
        username: username,
        accountPassword: accountPassword,
        masterPassword: masterPassword,
      );

      _pendingRegistration = pending;

      state = AuthState.awaitingTotpSetup(
        username: pending.username,
        handle: pending.handle,
      );
    } on AuthException catch (e) {
      _clearPendingRegistration();
      state = AuthState.guest(error: e.message);
    } catch (e) {
      _clearPendingRegistration();
      state = AuthState.guest(error: 'Registration failed: ${e.toString()}');
    }
  }

  /// Verifies the TOTP code during registration.
  ///
  /// If successful, transitions to [AuthStatus.awaitingRecoveryCodesAck]
  /// to show the user their recovery codes.
  Future<void> verifyTotpSetup(String totpCode) async {
    if (_pendingRegistration == null) {
      state = const AuthState.guest(error: 'No pending registration');
      return;
    }

    state = const AuthState.loading();

    try {
      final recoveryCodes = await _authRepository.registerWithPasswordFinish(
        pending: _pendingRegistration!,
        totpCode: totpCode,
      );

      _recoveryCodes = recoveryCodes;

      state = AuthState.awaitingRecoveryCodesAck(
        username: _pendingRegistration!.username,
        handle: _pendingRegistration!.handle,
      );
    } on AuthException catch (e) {
      state = AuthState.awaitingTotpSetup(
        username: _pendingRegistration!.username,
        handle: _pendingRegistration!.handle,
      ).copyWith(error: e.message);
    } catch (e) {
      state = AuthState.awaitingTotpSetup(
        username: _pendingRegistration!.username,
        handle: _pendingRegistration!.handle,
      ).copyWith(error: 'Verification failed: ${e.toString()}');
    }
  }

  /// Acknowledges the recovery codes and proceeds to login.
  ///
  /// After the user confirms they have saved the recovery codes,
  /// this method auto-logins with the registered credentials using
  /// the account password (for OPAQUE auth). The master password
  /// will be prompted separately.
  Future<void> acknowledgeRecoveryCodes() async {
    if (_pendingRegistration == null) {
      state = const AuthState.guest(error: 'No pending registration');
      return;
    }

    state = const AuthState.loading();

    try {
      // Auto-login with the registered account password (for OPAQUE auth)
      await login(
        username: _pendingRegistration!.username,
        password: _pendingRegistration!.accountPassword,
        savePassword: _pendingSavePassword,
      );

      // Clear registration state (login will handle the rest)
      _pendingRegistration = null;
      _recoveryCodes = null;
    } on AuthException catch (e) {
      state = AuthState.guest(error: e.message);
      _clearPendingRegistration();
    } catch (e) {
      state = AuthState.guest(error: 'Auto-login failed: ${e.toString()}');
      _clearPendingRegistration();
    }
  }

  /// Cancels the registration flow.
  void cancelRegistration() {
    _clearPendingRegistration();
    state = const AuthState.guest();
  }

  /// Logs out and clears the session.
  Future<void> logout() async {
    await _authRepository.logout();
    _session = null;
    _decryptedKeys = null;
    _loggedInWithPasskey = false;
    _clearPendingLogin();
    _clearPendingRegistration();
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
