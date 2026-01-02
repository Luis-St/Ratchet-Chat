import 'dart:convert';
import 'dart:typed_data';

import 'package:passkeys/types.dart';

import '../../core/errors/auth_exceptions.dart';
import '../models/kdf_params.dart';
import '../models/pending_2fa_login.dart';
import '../models/pending_registration.dart';
import '../models/user_session.dart';
import '../services/api_service.dart';
import '../services/crypto_service.dart';
import '../services/opaque_service.dart';
import '../services/passkey_service.dart';
import '../services/secure_storage_service.dart';
import '../services/totp_service.dart';

/// Response from login finish endpoint.
class LoginResponse {
  const LoginResponse({required this.token, required this.session});

  final String token;
  final UserSession session;
}

/// Repository for authentication operations.
class AuthRepository {
  AuthRepository({
    required ApiService apiService,
    required OpaqueService opaqueService,
    required CryptoService cryptoService,
    required SecureStorageService storageService,
    required PasskeyService passkeyService,
    required TotpService totpService,
  }) : _apiService = apiService,
       _opaqueService = opaqueService,
       _cryptoService = cryptoService,
       _storageService = storageService,
       _passkeyService = passkeyService,
       _totpService = totpService;

  final ApiService _apiService;
  final OpaqueService _opaqueService;
  final CryptoService _cryptoService;
  final SecureStorageService _storageService;
  final PasskeyService _passkeyService;
  final TotpService _totpService;

  /// Checks if passkeys are supported on the current platform.
  bool get isPasskeySupported => _passkeyService.isSupported;

  /// Gets KDF parameters for a user.
  Future<KdfParams> getKdfParams(String username) async {
    final response = await _apiService.get(
      '/auth/params/$username',
      includeAuth: false,
    );
    return KdfParams.fromJson(response);
  }

  /// Performs the full OPAQUE login flow.
  Future<UserSession> login({
    required String username,
    required String password,
    required bool savePassword,
  }) async {
    // Step 1: Get KDF parameters
    final kdfParams = await getKdfParams(username);

    // Step 2: Derive master key from password
    final masterKey = _cryptoService.deriveMasterKey(
      password: password,
      saltBase64: kdfParams.salt,
      iterations: kdfParams.iterations,
    );

    // Step 3: Start OPAQUE login
    final loginStart = _opaqueService.loginStart(password);
    final startResponse = await _apiService.post('/auth/opaque/login/start', {
      'username': username,
      'request': base64Encode(loginStart.request),
    }, includeAuth: false);

    // Step 4: Finish OPAQUE login
    final serverKe2 = base64Decode(startResponse['response'] as String);
    final loginFinish = _opaqueService.loginFinish(
      loginStart.client,
      Uint8List.fromList(serverKe2),
    );

    final finishResponse = await _apiService.post('/auth/opaque/login/finish', {
      'username': username,
      'finish': base64Encode(loginFinish.finishRequest),
    }, includeAuth: false);

    // Step 5: Extract session data
    final token = finishResponse['token'] as String;
    final keys = finishResponse['keys'] as Map<String, dynamic>;

    // Parse user ID from JWT
    final userId = _parseJwtSubject(token);

    // Build handle
    final serverHost = Uri.parse(_apiService.baseUrl!).host;
    final handle = '$username@$serverHost';

    final session = UserSession(
      token: token,
      userId: userId,
      username: username,
      handle: handle,
      kdfSalt: keys['kdf_salt'] as String,
      kdfIterations: keys['kdf_iterations'] as int,
      encryptedIdentityKey: EncryptedPayload(
        ciphertext: keys['encrypted_identity_key'] as String,
        iv: keys['encrypted_identity_iv'] as String,
      ),
      encryptedTransportKey: EncryptedPayload(
        ciphertext: keys['encrypted_transport_key'] as String,
        iv: keys['encrypted_transport_iv'] as String,
      ),
      publicIdentityKey: keys['public_identity_key'] as String,
      publicTransportKey: keys['public_transport_key'] as String,
    );

    // Step 6: Save session
    await _storageService.saveSession(session);

    // Step 7: Optionally save master key
    if (savePassword) {
      await _storageService.saveMasterKey(_cryptoService.exportKey(masterKey));
    }

    // Step 8: Set token for future API calls
    _apiService.setToken(token);

    return session;
  }

  /// Unlocks an existing session by re-deriving the master key.
  Future<DecryptedKeys> unlock({
    required String password,
    required UserSession session,
  }) async {
    // Derive master key
    final masterKey = _cryptoService.deriveMasterKey(
      password: password,
      saltBase64: session.kdfSalt,
      iterations: session.kdfIterations,
    );

    try {
      // Decrypt keys
      final identityKey = _cryptoService.decrypt(
        session.encryptedIdentityKey,
        masterKey,
      );
      final transportKey = _cryptoService.decrypt(
        session.encryptedTransportKey,
        masterKey,
      );

      return DecryptedKeys(
        identityPrivateKey: identityKey,
        transportPrivateKey: transportKey,
      );
    } catch (e) {
      throw const DecryptionException('Invalid password');
    }
  }

  /// Gets the stored session, if any.
  Future<UserSession?> getSession() async {
    return _storageService.getSession();
  }

  /// Gets the stored master key, if any.
  Future<Uint8List?> getMasterKey() async {
    final base64Key = await _storageService.getMasterKey();
    if (base64Key == null) return null;
    return _cryptoService.importKey(base64Key);
  }

  /// Performs the full OPAQUE registration flow.
  Future<UserSession> register({
    required String username,
    required String password,
    required bool savePassword,
  }) async {
    // Step 1: Generate KDF parameters
    final kdfSalt = base64Encode(_cryptoService.generateSalt());
    const kdfIterations = 310000;

    // Step 2: Derive master key from password
    final masterKey = _cryptoService.deriveMasterKey(
      password: password,
      saltBase64: kdfSalt,
      iterations: kdfIterations,
    );

    // Step 3: Start OPAQUE registration
    final regStart = _opaqueService.registerStart(password);
    final startResponse = await _apiService.post('/auth/opaque/register/start', {
      'username': username,
      'request': base64Encode(regStart.request),
    }, includeAuth: false);

    // Step 4: Finish OPAQUE registration
    final serverResponse = base64Decode(startResponse['response'] as String);
    final registrationRecord = _opaqueService.registerFinish(
      regStart.client,
      Uint8List.fromList(serverResponse),
    );

    // Step 5: Generate key pairs (placeholder - actual implementation would use ML-DSA and ML-KEM)
    // For now, we'll generate random bytes as placeholders
    final identityPrivateKey = _cryptoService.generateSalt(64);
    final transportPrivateKey = _cryptoService.generateSalt(64);
    final publicIdentityKey = _cryptoService.generateSalt(32);
    final publicTransportKey = _cryptoService.generateSalt(32);

    // Step 6: Encrypt private keys with master key
    final encryptedIdentityKey = _cryptoService.encrypt(identityPrivateKey, masterKey);
    final encryptedTransportKey = _cryptoService.encrypt(transportPrivateKey, masterKey);

    // Step 7: Send finish request to server
    await _apiService.post('/auth/opaque/register/finish', {
      'username': username,
      'finish': base64Encode(registrationRecord),
      'kdf_salt': kdfSalt,
      'kdf_iterations': kdfIterations,
      'public_identity_key': base64Encode(publicIdentityKey),
      'public_transport_key': base64Encode(publicTransportKey),
      'encrypted_identity_key': encryptedIdentityKey.ciphertext,
      'encrypted_identity_iv': encryptedIdentityKey.iv,
      'encrypted_transport_key': encryptedTransportKey.ciphertext,
      'encrypted_transport_iv': encryptedTransportKey.iv,
    }, includeAuth: false);

    // Step 8: Now login to get a session token
    return login(
      username: username,
      password: password,
      savePassword: savePassword,
    );
  }

  /// Logs out the current session.
  Future<void> logout() async {
    try {
      await _apiService.delete('/auth/sessions/current');
    } catch (_) {
      // Ignore errors during logout
    }
    await _storageService.clearSession();
    _apiService.setToken(null);
  }

  /// Parses the subject (user ID) from a JWT token.
  String _parseJwtSubject(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw const ServerException('Invalid token format');
    }

    final payload = parts[1];
    // Add padding if needed
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final json = jsonDecode(decoded) as Map<String, dynamic>;

    return json['sub'] as String;
  }

  // ============== PASSKEY AUTHENTICATION METHODS ==============

  /// Performs the combined passkey + OPAQUE registration flow.
  ///
  /// This is the primary registration method when passkeys are supported.
  /// Creates a passkey credential along with OPAQUE password authentication.
  Future<UserSession> registerWithPasskey({
    required String username,
    required String password,
    required bool savePassword,
  }) async {
    if (!isPasskeySupported) {
      throw const PasskeyNotSupportedException();
    }

    // Step 1: Generate KDF parameters
    final kdfSalt = base64Encode(_cryptoService.generateSalt());
    const kdfIterations = 310000;

    // Step 2: Derive master key from password
    final masterKey = _cryptoService.deriveMasterKey(
      password: password,
      saltBase64: kdfSalt,
      iterations: kdfIterations,
    );

    // Step 3: Generate key pairs (placeholder - actual implementation would use ML-DSA and ML-KEM)
    final identityPrivateKey = _cryptoService.generateSalt(64);
    final transportPrivateKey = _cryptoService.generateSalt(64);
    final publicIdentityKey = _cryptoService.generateSalt(32);
    final publicTransportKey = _cryptoService.generateSalt(32);

    // Step 4: Encrypt private keys with master key
    final encryptedIdentityKey = _cryptoService.encrypt(identityPrivateKey, masterKey);
    final encryptedTransportKey = _cryptoService.encrypt(transportPrivateKey, masterKey);

    // Step 5: Start OPAQUE registration
    final regStart = _opaqueService.registerStart(password);

    // Step 6: Start passkey registration (get creation options)
    final startResponse = await _apiService.passkeyRegisterStart(
      username: username,
      opaqueRequest: base64Encode(regStart.request),
    );

    final opaqueResponse = startResponse['opaque_response'] as String;
    final passkeyOptions = startResponse['passkey_options'] as Map<String, dynamic>;

    // Step 7: Create passkey credential
    final rpId = passkeyOptions['rp']?['id'] as String? ??
        Uri.parse(_apiService.baseUrl!).host;
    final rpName = passkeyOptions['rp']?['name'] as String? ?? 'Ratchet Chat';
    final user = passkeyOptions['user'] as Map<String, dynamic>;
    final challenge = passkeyOptions['challenge'] as String;
    final excludeCredentials = (passkeyOptions['excludeCredentials'] as List?)
        ?.map((c) => c['id'] as String)
        .toList();

    final passkeyResponse = await _passkeyService.createCredential(
      relyingPartyId: rpId,
      relyingPartyName: rpName,
      userId: user['id'] as String,
      userName: user['name'] as String,
      userDisplayName: user['displayName'] as String,
      challenge: challenge,
      excludeCredentialIds: excludeCredentials,
    );

    // Step 8: Finish OPAQUE registration
    final serverResponse = base64Decode(opaqueResponse);
    final registrationRecord = _opaqueService.registerFinish(
      regStart.client,
      Uint8List.fromList(serverResponse),
    );

    // Step 9: Complete registration with server
    final finishResponse = await _apiService.passkeyRegisterFinish(
      username: username,
      opaqueFinish: base64Encode(registrationRecord),
      passkeyResponse: passkeyResponse.toJson(),
      kdfSalt: kdfSalt,
      kdfIterations: kdfIterations,
      publicIdentityKey: base64Encode(publicIdentityKey),
      publicTransportKey: base64Encode(publicTransportKey),
      encryptedIdentityKey: encryptedIdentityKey.ciphertext,
      encryptedIdentityIv: encryptedIdentityKey.iv,
      encryptedTransportKey: encryptedTransportKey.ciphertext,
      encryptedTransportIv: encryptedTransportKey.iv,
    );

    // Step 10: Extract session data
    final token = finishResponse['token'] as String;
    final userId = _parseJwtSubject(token);
    final serverHost = Uri.parse(_apiService.baseUrl!).host;
    final handle = '$username@$serverHost';

    final session = UserSession(
      token: token,
      userId: userId,
      username: username,
      handle: handle,
      kdfSalt: kdfSalt,
      kdfIterations: kdfIterations,
      encryptedIdentityKey: encryptedIdentityKey,
      encryptedTransportKey: encryptedTransportKey,
      publicIdentityKey: base64Encode(publicIdentityKey),
      publicTransportKey: base64Encode(publicTransportKey),
    );

    // Step 11: Save session
    await _storageService.saveSession(session);

    // Step 12: Optionally save master key
    if (savePassword) {
      await _storageService.saveMasterKey(_cryptoService.exportKey(masterKey));
    }

    // Step 13: Set token for future API calls
    _apiService.setToken(token);

    return session;
  }

  /// Logs in using passkey only.
  ///
  /// After successful passkey login, the user will be in a "locked" state
  /// and must enter their password to decrypt the private keys.
  Future<UserSession> loginWithPasskey() async {
    if (!isPasskeySupported) {
      throw const PasskeyNotSupportedException();
    }

    // Step 1: Get passkey login options
    final options = await _apiService.passkeyLoginOptions();

    // Step 2: Parse options
    final rpId = options['rpId'] as String? ??
        Uri.parse(_apiService.baseUrl!).host;
    final challenge = options['challenge'] as String;
    final allowCredentials = (options['allowCredentials'] as List?)
        ?.map((c) => CredentialType(
              type: c['type'] as String? ?? 'public-key',
              id: c['id'] as String,
              transports: (c['transports'] as List?)?.cast<String>() ?? [],
            ))
        .toList();

    // Step 3: Authenticate with passkey
    final authResponse = await _passkeyService.authenticate(
      relyingPartyId: rpId,
      challenge: challenge,
      allowCredentials: allowCredentials,
    );

    // Step 4: Finish login
    final loginResponse = await _apiService.passkeyLoginFinish(
      response: authResponse.toJson(),
    );

    // Step 5: Extract session data
    final token = loginResponse['token'] as String;
    final user = loginResponse['user'] as Map<String, dynamic>;
    final keys = loginResponse['keys'] as Map<String, dynamic>;

    final userId = user['id'] as String;
    final username = user['username'] as String;
    final serverHost = Uri.parse(_apiService.baseUrl!).host;
    final handle = '$username@$serverHost';

    final session = UserSession(
      token: token,
      userId: userId,
      username: username,
      handle: handle,
      kdfSalt: keys['kdf_salt'] as String,
      kdfIterations: keys['kdf_iterations'] as int,
      encryptedIdentityKey: EncryptedPayload(
        ciphertext: keys['encrypted_identity_key'] as String,
        iv: keys['encrypted_identity_iv'] as String,
      ),
      encryptedTransportKey: EncryptedPayload(
        ciphertext: keys['encrypted_transport_key'] as String,
        iv: keys['encrypted_transport_iv'] as String,
      ),
      publicIdentityKey: keys['public_identity_key'] as String,
      publicTransportKey: keys['public_transport_key'] as String,
    );

    // Step 6: Save session (but NOT master key - user must unlock)
    await _storageService.saveSession(session);

    // Step 7: Set token for future API calls
    _apiService.setToken(token);

    return session;
  }

  /// Unlocks a session after passkey login by verifying the password via OPAQUE.
  ///
  /// This method is called when the user is in a "locked" state after passkey login.
  /// It verifies the password using OPAQUE and then decrypts the private keys.
  Future<DecryptedKeys> unlockWithOpaqueVerification({
    required String password,
    required UserSession session,
    required bool savePassword,
  }) async {
    // Step 1: Derive master key
    final masterKey = _cryptoService.deriveMasterKey(
      password: password,
      saltBase64: session.kdfSalt,
      iterations: session.kdfIterations,
    );

    // Step 2: Start OPAQUE unlock
    final unlockStart = _opaqueService.loginStart(password);
    final startResponse = await _apiService.opaqueUnlockStart(
      request: base64Encode(unlockStart.request),
    );

    // Step 3: Finish OPAQUE unlock
    final serverKe2 = base64Decode(startResponse['response'] as String);
    final unlockFinish = _opaqueService.loginFinish(
      unlockStart.client,
      Uint8List.fromList(serverKe2),
    );

    await _apiService.opaqueUnlockFinish(
      finish: base64Encode(unlockFinish.finishRequest),
    );

    // Step 4: Decrypt keys
    try {
      final identityKey = _cryptoService.decrypt(
        session.encryptedIdentityKey,
        masterKey,
      );
      final transportKey = _cryptoService.decrypt(
        session.encryptedTransportKey,
        masterKey,
      );

      // Step 5: Optionally save master key
      if (savePassword) {
        await _storageService.saveMasterKey(_cryptoService.exportKey(masterKey));
      }

      return DecryptedKeys(
        identityPrivateKey: identityKey,
        transportPrivateKey: transportKey,
      );
    } catch (e) {
      throw const DecryptionException('Invalid password');
    }
  }

  // ============== PASSWORD + 2FA LOGIN METHODS ==============

  /// Performs the password + 2FA login flow.
  ///
  /// Returns either:
  /// - A [Pending2faLogin] if 2FA is required
  /// - A [UserSession] if 2FA is not required (no 2FA enabled on account)
  Future<({Pending2faLogin? pending2fa, UserSession? session})> loginWithPassword({
    required String username,
    required String password,
  }) async {
    // Step 1: Get KDF parameters
    final kdfParams = await getKdfParams(username);

    // Step 2: Start OPAQUE login
    final loginStart = _opaqueService.loginStart(password);
    final startResponse = await _apiService.passwordLoginStart(
      username: username,
      opaqueRequest: base64Encode(loginStart.request),
    );

    // Step 3: Finish OPAQUE login
    final serverKe2 = base64Decode(startResponse['opaque_response'] as String);
    final loginFinish = _opaqueService.loginFinish(
      loginStart.client,
      Uint8List.fromList(serverKe2),
    );

    final finishResponse = await _apiService.passwordLoginFinish(
      username: username,
      opaqueFinish: base64Encode(loginFinish.finishRequest),
    );

    // Step 4: Check if 2FA is required
    final requires2fa = finishResponse['requires_2fa'] as bool? ?? false;
    final serverHost = Uri.parse(_apiService.baseUrl!).host;
    final handle = '$username@$serverHost';

    if (requires2fa) {
      // Return pending 2FA login with session ticket
      final sessionTicket = finishResponse['session_ticket'] as String;
      return (
        pending2fa: Pending2faLogin(
          username: username,
          handle: handle,
          sessionTicket: sessionTicket,
          kdfSalt: kdfParams.salt,
          kdfIterations: kdfParams.iterations,
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        ),
        session: null,
      );
    } else {
      // No 2FA, return session directly
      final session = _buildSessionFromResponse(
        username: username,
        handle: handle,
        kdfSalt: kdfParams.salt,
        kdfIterations: kdfParams.iterations,
        response: finishResponse,
      );
      return (pending2fa: null, session: session);
    }
  }

  /// Verifies a TOTP code during password + 2FA login.
  ///
  /// Returns the [UserSession] if verification succeeds.
  Future<UserSession> verifyTotp({
    required Pending2faLogin pendingLogin,
    required String totpCode,
  }) async {
    if (pendingLogin.isExpired) {
      throw const SessionTicketExpiredException();
    }

    final response = await _apiService.verifyTotp(
      sessionTicket: pendingLogin.sessionTicket,
      totpCode: totpCode,
    );

    return _buildSessionFromResponse(
      username: pendingLogin.username,
      handle: pendingLogin.handle,
      kdfSalt: pendingLogin.kdfSalt,
      kdfIterations: pendingLogin.kdfIterations,
      response: response,
    );
  }

  /// Verifies a recovery code during password + 2FA login.
  ///
  /// Returns the [UserSession] and remaining recovery codes count.
  Future<({UserSession session, int remainingCodes})> verifyRecoveryCode({
    required Pending2faLogin pendingLogin,
    required String recoveryCode,
  }) async {
    if (pendingLogin.isExpired) {
      throw const SessionTicketExpiredException();
    }

    final response = await _apiService.verifyRecoveryCode(
      sessionTicket: pendingLogin.sessionTicket,
      recoveryCode: recoveryCode,
    );

    final session = _buildSessionFromResponse(
      username: pendingLogin.username,
      handle: pendingLogin.handle,
      kdfSalt: pendingLogin.kdfSalt,
      kdfIterations: pendingLogin.kdfIterations,
      response: response,
    );

    final remainingCodes = response['remaining_recovery_codes'] as int? ?? 0;

    return (session: session, remainingCodes: remainingCodes);
  }

  /// Builds a [UserSession] from the server response after successful auth.
  UserSession _buildSessionFromResponse({
    required String username,
    required String handle,
    required String kdfSalt,
    required int kdfIterations,
    required Map<String, dynamic> response,
  }) {
    final token = response['token'] as String;
    final keys = response['keys'] as Map<String, dynamic>;
    final userId = _parseJwtSubject(token);

    return UserSession(
      token: token,
      userId: userId,
      username: username,
      handle: handle,
      kdfSalt: keys['kdf_salt'] as String? ?? kdfSalt,
      kdfIterations: keys['kdf_iterations'] as int? ?? kdfIterations,
      encryptedIdentityKey: EncryptedPayload(
        ciphertext: keys['encrypted_identity_key'] as String,
        iv: keys['encrypted_identity_iv'] as String,
      ),
      encryptedTransportKey: EncryptedPayload(
        ciphertext: keys['encrypted_transport_key'] as String,
        iv: keys['encrypted_transport_iv'] as String,
      ),
      publicIdentityKey: keys['public_identity_key'] as String,
      publicTransportKey: keys['public_transport_key'] as String,
    );
  }

  /// Saves a session and optionally the master key.
  Future<void> saveSession({
    required UserSession session,
    required Uint8List masterKey,
    required bool savePassword,
  }) async {
    await _storageService.saveSession(session);
    _apiService.setToken(session.token);

    if (savePassword) {
      await _storageService.saveMasterKey(_cryptoService.exportKey(masterKey));
    }
  }

  // ============== PASSWORD + 2FA REGISTRATION METHODS ==============

  /// Starts the password+2FA registration flow.
  ///
  /// Returns a [PendingRegistration] containing all the data needed
  /// for the TOTP setup screen (QR code, secret, etc.).
  Future<PendingRegistration> registerWithPasswordStart({
    required String username,
    required String password,
  }) async {
    // Step 1: Generate KDF parameters
    final kdfSalt = base64Encode(_cryptoService.generateSalt());
    const kdfIterations = 310000;

    // Step 2: Derive master key from password
    final masterKey = _cryptoService.deriveMasterKey(
      password: password,
      saltBase64: kdfSalt,
      iterations: kdfIterations,
    );

    // Step 3: Generate key pairs (placeholder - actual implementation would use ML-DSA and ML-KEM)
    final identityPrivateKey = _cryptoService.generateSalt(64);
    final transportPrivateKey = _cryptoService.generateSalt(64);
    final publicIdentityKey = _cryptoService.generateSalt(32);
    final publicTransportKey = _cryptoService.generateSalt(32);

    // Step 4: Encrypt private keys with master key
    final encryptedIdentityKey = _cryptoService.encrypt(identityPrivateKey, masterKey);
    final encryptedTransportKey = _cryptoService.encrypt(transportPrivateKey, masterKey);

    // Step 5: Generate TOTP secret and encrypt it
    final totpSecret = _totpService.generateSecret();
    final totpSecretBytes = Uint8List.fromList(totpSecret.codeUnits);
    final encryptedTotpSecret = _cryptoService.encrypt(totpSecretBytes, masterKey);

    // Step 6: Start OPAQUE registration
    final regStart = _opaqueService.registerStart(password);
    final startResponse = await _apiService.passwordRegisterStart(
      username: username,
      opaqueRequest: base64Encode(regStart.request),
    );

    // Step 7: Construct handle from username and server host
    final serverHost = Uri.parse(_apiService.baseUrl!).host;
    final handle = '$username@$serverHost';

    // Step 8: Finish OPAQUE registration (get record but don't send yet)
    final serverResponse = base64Decode(startResponse['opaque_response'] as String);
    final registrationRecord = _opaqueService.registerFinish(
      regStart.client,
      Uint8List.fromList(serverResponse),
    );

    // Step 9: Generate TOTP URI for QR code
    final totpUri = _totpService.getTotpUri(
      secret: totpSecret,
      username: '$username@$serverHost',
      issuer: 'Ratchet Chat',
    );

    return PendingRegistration(
      username: username,
      handle: handle,
      password: password,
      kdfSalt: kdfSalt,
      kdfIterations: kdfIterations,
      masterKey: masterKey,
      opaqueFinish: base64Encode(registrationRecord),
      totpSecret: totpSecret,
      totpUri: totpUri,
      encryptedIdentityKey: encryptedIdentityKey,
      encryptedTransportKey: encryptedTransportKey,
      encryptedTotpSecret: encryptedTotpSecret,
      publicIdentityKey: base64Encode(publicIdentityKey),
      publicTransportKey: base64Encode(publicTransportKey),
    );
  }

  /// Completes the password+2FA registration flow after TOTP verification.
  ///
  /// Returns the list of recovery codes from the server.
  Future<List<String>> registerWithPasswordFinish({
    required PendingRegistration pending,
    required String totpCode,
  }) async {
    // Send the finish request with TOTP code
    final response = await _apiService.passwordRegisterFinish(
      username: pending.username,
      opaqueFinish: pending.opaqueFinish,
      kdfSalt: pending.kdfSalt,
      kdfIterations: pending.kdfIterations,
      publicIdentityKey: pending.publicIdentityKey,
      publicTransportKey: pending.publicTransportKey,
      encryptedIdentityKey: pending.encryptedIdentityKey.ciphertext,
      encryptedIdentityIv: pending.encryptedIdentityKey.iv,
      encryptedTransportKey: pending.encryptedTransportKey.ciphertext,
      encryptedTransportIv: pending.encryptedTransportKey.iv,
      totpSecret: pending.totpSecret,
      encryptedTotpSecret: pending.encryptedTotpSecret.ciphertext,
      encryptedTotpSecretIv: pending.encryptedTotpSecret.iv,
      totpCode: totpCode,
    );

    // Extract recovery codes from response
    final recoveryCodes = (response['recovery_codes'] as List<dynamic>)
        .map((code) => code as String)
        .toList();

    return recoveryCodes;
  }
}
