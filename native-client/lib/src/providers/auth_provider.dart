// Authentication state management with OPAQUE protocol support.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../crypto/crypto.dart';
import '../db/db.dart';
import '../opaque/opaque.dart';

/// Authentication state.
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? userId;
  final String? handle;
  final String? sessionToken;
  final IdentityKeyPair? identityKeys;
  final TransportKeyPair? transportKeys;
  final Uint8List? encryptionKey;
  final Uint8List? exportKey;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.userId,
    this.handle,
    this.sessionToken,
    this.identityKeys,
    this.transportKeys,
    this.encryptionKey,
    this.exportKey,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? userId,
    String? handle,
    String? sessionToken,
    IdentityKeyPair? identityKeys,
    TransportKeyPair? transportKeys,
    Uint8List? encryptionKey,
    Uint8List? exportKey,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      userId: userId ?? this.userId,
      handle: handle ?? this.handle,
      sessionToken: sessionToken ?? this.sessionToken,
      identityKeys: identityKeys ?? this.identityKeys,
      transportKeys: transportKeys ?? this.transportKeys,
      encryptionKey: encryptionKey ?? this.encryptionKey,
      exportKey: exportKey ?? this.exportKey,
      error: error,
    );
  }

  static const AuthState initial = AuthState();
}

/// Authentication provider with OPAQUE protocol support.
class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.initial;
  final ApiClient _apiClient;
  final AuthApi _authApi;
  final AuthDao _authDao;

  AuthProvider({
    required ApiClient apiClient,
    AuthDao? authDao,
  })  : _apiClient = apiClient,
        _authApi = AuthApi(apiClient),
        _authDao = authDao ?? AuthDao() {
    // Set up token provider for API client
    _apiClient.setTokenProvider(() async => _state.sessionToken);
  }

  /// Current authentication state.
  AuthState get state => _state;

  /// Whether the user is authenticated.
  bool get isAuthenticated => _state.isAuthenticated;

  /// Current user's handle.
  String? get handle => _state.handle;

  /// Current session token.
  String? get sessionToken => _state.sessionToken;

  // ============== State Management ==============

  void _setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _setState(_state.copyWith(isLoading: loading, error: null));
  }

  void _setError(String error) {
    _setState(_state.copyWith(isLoading: false, error: error));
  }

  // ============== Initialization ==============

  /// Initialize auth state from local storage.
  Future<void> initialize() async {
    _setLoading(true);

    try {
      // Load auth state from database
      final dbState = await _authDao.getAuthState();

      if (dbState.loggedIn && dbState.sessionToken != null) {
        // Load keys from secure storage
        final keyBundle = await KeyManager.loadKeyBundle();

        if (keyBundle != null) {
          _setState(AuthState(
            isAuthenticated: true,
            isLoading: false,
            userId: dbState.userId,
            handle: dbState.handle,
            sessionToken: dbState.sessionToken,
            identityKeys: keyBundle.identityKeys,
            transportKeys: keyBundle.transportKeys,
            encryptionKey: keyBundle.encryptionKey,
            exportKey: keyBundle.exportKey,
          ));

          // Verify session is still valid
          await _verifySession();
          return;
        }
      }

      // Not logged in
      _setState(AuthState.initial);
    } catch (e) {
      _setError('Failed to initialize: $e');
    }
  }

  /// Verify the current session is still valid.
  Future<void> _verifySession() async {
    try {
      await _authApi.getCurrentUser();
    } catch (e) {
      // Session invalid - logout
      await logout();
    }
  }

  // ============== OPAQUE Registration ==============

  /// Register a new user with OPAQUE.
  Future<void> register(String handleInput, String password) async {
    _setLoading(true);

    try {
      // Generate post-quantum keys
      final identityKeys = MlDsa65.generateKeyPair();
      final transportKeys = MlKem768.generateKeyPair();

      // Create OPAQUE client
      final config = getOpaqueConfig(OpaqueId.opaqueP256);
      final opaqueClient = OpaqueClient(config);

      // Start registration
      final regRequest = opaqueClient.registerInit(password);
      final regRequestB64 = base64Encode(regRequest.serialize());

      // Send to server
      final regResponse = await _authApi.registerInit(
        handle: handleInput,
        registrationRequest: regRequestB64,
      );

      // Parse server response
      final responseBytes = base64Decode(regResponse.evaluation);
      final serverPubKeyBytes = base64Decode(regResponse.serverPublicKey);

      // Create registration response for OPAQUE client
      final opaqueResponse = RegistrationResponse(
        evaluation: responseBytes,
        serverPublicKey: serverPubKeyBytes,
      );

      // Finish registration
      final regResult = opaqueClient.registerFinish(opaqueResponse);

      // Send registration record to server
      await _authApi.registerFinish(
        handle: handleInput,
        registrationRecord: base64Encode(regResult.record.serialize()),
        identityPublicKey: base64Encode(identityKeys.publicKey),
        transportPublicKey: base64Encode(transportKeys.publicKey),
      );

      // Derive encryption key from export key
      final exportKeyBytes = Uint8List.fromList(regResult.exportKey);
      final encryptionKey = AesGcm.deriveKey(
        password,
        exportKeyBytes,
        iterations: 100000,
      );

      // Store keys securely
      final keyBundle = KeyBundle(
        identityKeys: identityKeys,
        transportKeys: transportKeys,
        encryptionKey: encryptionKey,
        exportKey: exportKeyBytes,
      );
      await KeyManager.storeKeyBundle(keyBundle);

      _setState(_state.copyWith(
        isLoading: false,
        error: null,
      ));

      // Now login automatically
      await login(handleInput, password);
    } catch (e) {
      _setError('Registration failed: $e');
    }
  }

  // ============== OPAQUE Login ==============

  /// Login with OPAQUE.
  Future<void> login(String handleInput, String password) async {
    _setLoading(true);

    try {
      // Create OPAQUE client
      final config = getOpaqueConfig(OpaqueId.opaqueP256);
      final opaqueClient = OpaqueClient(config);

      // Start authentication
      final ke1 = opaqueClient.authInit(password);
      final ke1B64 = base64Encode(ke1.serialize());

      // Send KE1 to server, receive KE2
      final loginResponse = await _authApi.loginInit(
        handle: handleInput,
        ke1: ke1B64,
      );

      // Parse KE2 from server response
      final credentialResponse = base64Decode(loginResponse.credentialResponse);
      final serverNonce = base64Decode(loginResponse.serverNonce);
      final serverKeyshare = base64Decode(loginResponse.serverKeyshare);
      final serverMac = base64Decode(loginResponse.serverMac);

      // Reconstruct KE2
      final ke2 = _reconstructKE2(
        config,
        credentialResponse,
        serverNonce,
        serverKeyshare,
        serverMac,
      );

      // Finish authentication
      final authResult = opaqueClient.authFinish(ke2);

      // Send KE3 to server
      final ke3B64 = base64Encode(authResult.ke3.serialize());
      final finishResponse = await _authApi.loginFinish(
        handle: handleInput,
        ke3: ke3B64,
      );

      // Derive encryption key from export key
      final loginExportKey = Uint8List.fromList(authResult.exportKey);
      final encryptionKey = AesGcm.deriveKey(
        password,
        loginExportKey,
        iterations: 100000,
      );

      // Load or generate keys
      var identityKeys = await KeyManager.loadIdentityKeys();
      var transportKeys = await KeyManager.loadTransportKeys();

      if (identityKeys == null || transportKeys == null) {
        // Keys not stored locally - generate new ones
        identityKeys = MlDsa65.generateKeyPair();
        transportKeys = MlKem768.generateKeyPair();

        // Update server with new public keys
        await _authApi.updateSettings(UserSettings(
          identityPublicKey: base64Encode(identityKeys.publicKey),
          transportPublicKey: base64Encode(transportKeys.publicKey),
        ));
      }

      // Store everything
      final keyBundle = KeyBundle(
        identityKeys: identityKeys,
        transportKeys: transportKeys,
        encryptionKey: encryptionKey,
        exportKey: loginExportKey,
      );
      await KeyManager.storeKeyBundle(keyBundle);

      // Store auth state in database
      await _authDao.login(
        userId: finishResponse.userId,
        handle: finishResponse.handle,
        sessionToken: finishResponse.token,
        identityPublicKey: identityKeys.publicKey,
        transportPublicKey: transportKeys.publicKey,
      );

      // Update state
      _setState(AuthState(
        isAuthenticated: true,
        isLoading: false,
        userId: finishResponse.userId,
        handle: finishResponse.handle,
        sessionToken: finishResponse.token,
        identityKeys: identityKeys,
        transportKeys: transportKeys,
        encryptionKey: encryptionKey,
        exportKey: loginExportKey,
      ));
    } catch (e) {
      _setError('Login failed: $e');
    }
  }

  /// Reconstruct KE2 from server response components.
  KE2 _reconstructKE2(
    OpaqueConfig config,
    Uint8List credentialResponse,
    Uint8List serverNonce,
    Uint8List serverKeyshare,
    Uint8List serverMac,
  ) {
    // Parse credential response to extract evaluation, masking nonce, and masked response
    final response = CredentialResponse.deserialize(config, credentialResponse.toList());

    final authResponse = AuthResponse(
      serverNonce: serverNonce,
      serverKeyshare: serverKeyshare,
      serverMac: serverMac,
    );

    return KE2(response: response, authResponse: authResponse);
  }

  // ============== Passkey Authentication ==============

  /// Login with passkey.
  Future<void> loginWithPasskey(String handleInput) async {
    _setLoading(true);

    try {
      // Get passkey login options
      final options = await _authApi.getPasskeyLoginOptions(handle: handleInput);

      // TODO: Use passkeys package to authenticate with WebAuthn
      // This requires platform-specific implementation
      throw UnimplementedError('Passkey login not yet implemented');
    } catch (e) {
      _setError('Passkey login failed: $e');
    }
  }

  /// Register a new passkey.
  Future<void> registerPasskey() async {
    if (!isAuthenticated) {
      _setError('Must be logged in to register a passkey');
      return;
    }

    _setLoading(true);

    try {
      // Get passkey registration options
      final options = await _authApi.getPasskeyRegisterOptions();

      // TODO: Use passkeys package to register with WebAuthn
      // This requires platform-specific implementation
      throw UnimplementedError('Passkey registration not yet implemented');
    } catch (e) {
      _setError('Passkey registration failed: $e');
    }
  }

  // ============== Logout ==============

  /// Logout and clear all local data.
  Future<void> logout() async {
    try {
      // Notify server
      if (_state.sessionToken != null) {
        try {
          await _authApi.logout();
        } catch (_) {
          // Ignore server errors during logout
        }
      }
    } finally {
      // Clear local state
      await _authDao.logout();
      await KeyManager.clearAllKeys();

      _setState(AuthState.initial);
    }
  }

  // ============== Key Management ==============

  /// Rotate transport keys.
  Future<void> rotateTransportKeys() async {
    if (!isAuthenticated) {
      _setError('Must be logged in to rotate keys');
      return;
    }

    _setLoading(true);

    try {
      // Generate new transport keys
      final newTransportKeys = await KeyManager.rotateTransportKeys();

      // Update server
      await _authApi.updateSettings(UserSettings(
        transportPublicKey: base64Encode(newTransportKeys.publicKey),
      ));

      // Update state
      _setState(_state.copyWith(
        isLoading: false,
        transportKeys: newTransportKeys,
      ));
    } catch (e) {
      _setError('Key rotation failed: $e');
    }
  }
}
