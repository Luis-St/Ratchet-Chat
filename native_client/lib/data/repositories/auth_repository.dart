import 'dart:convert';
import 'dart:typed_data';

import '../../core/errors/auth_exceptions.dart';
import '../models/kdf_params.dart';
import '../models/user_session.dart';
import '../services/api_service.dart';
import '../services/crypto_service.dart';
import '../services/opaque_service.dart';
import '../services/secure_storage_service.dart';

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
  }) : _apiService = apiService,
       _opaqueService = opaqueService,
       _cryptoService = cryptoService,
       _storageService = storageService;

  final ApiService _apiService;
  final OpaqueService _opaqueService;
  final CryptoService _cryptoService;
  final SecureStorageService _storageService;

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
}
