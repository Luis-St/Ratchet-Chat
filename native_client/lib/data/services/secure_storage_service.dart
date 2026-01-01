import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/storage_keys.dart';
import '../models/server_config.dart';
import '../models/user_session.dart';

/// Service for securely storing sensitive data.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  // Server configuration

  /// Saves the server configuration.
  Future<void> saveServer(ServerConfig config) async {
    await _storage.write(key: StorageKeys.savedServerUrl, value: config.url);
    if (config.name != null) {
      await _storage.write(
        key: StorageKeys.savedServerName,
        value: config.name,
      );
    }
  }

  /// Gets the saved server configuration, if any.
  Future<ServerConfig?> getSavedServer() async {
    final url = await _storage.read(key: StorageKeys.savedServerUrl);
    if (url == null) return null;

    final name = await _storage.read(key: StorageKeys.savedServerName);
    return ServerConfig(url: url, name: name, isSaved: true);
  }

  /// Clears the saved server configuration.
  Future<void> clearSavedServer() async {
    await _storage.delete(key: StorageKeys.savedServerUrl);
    await _storage.delete(key: StorageKeys.savedServerName);
  }

  // Session data

  /// Saves the user session.
  Future<void> saveSession(UserSession session) async {
    await Future.wait([
      _storage.write(key: StorageKeys.authToken, value: session.token),
      _storage.write(key: StorageKeys.userId, value: session.userId),
      _storage.write(key: StorageKeys.username, value: session.username),
      _storage.write(key: StorageKeys.userHandle, value: session.handle),
      _storage.write(key: StorageKeys.kdfSalt, value: session.kdfSalt),
      _storage.write(
        key: StorageKeys.kdfIterations,
        value: session.kdfIterations.toString(),
      ),
      _storage.write(
        key: StorageKeys.encryptedIdentityKey,
        value: session.encryptedIdentityKey.ciphertext,
      ),
      _storage.write(
        key: StorageKeys.encryptedIdentityIv,
        value: session.encryptedIdentityKey.iv,
      ),
      _storage.write(
        key: StorageKeys.encryptedTransportKey,
        value: session.encryptedTransportKey.ciphertext,
      ),
      _storage.write(
        key: StorageKeys.encryptedTransportIv,
        value: session.encryptedTransportKey.iv,
      ),
      _storage.write(
        key: StorageKeys.publicIdentityKey,
        value: session.publicIdentityKey,
      ),
      _storage.write(
        key: StorageKeys.publicTransportKey,
        value: session.publicTransportKey,
      ),
    ]);
  }

  /// Gets the saved session, if any.
  Future<UserSession?> getSession() async {
    final token = await _storage.read(key: StorageKeys.authToken);
    if (token == null) return null;

    final userId = await _storage.read(key: StorageKeys.userId);
    final username = await _storage.read(key: StorageKeys.username);
    final handle = await _storage.read(key: StorageKeys.userHandle);
    final kdfSalt = await _storage.read(key: StorageKeys.kdfSalt);
    final kdfIterationsStr = await _storage.read(
      key: StorageKeys.kdfIterations,
    );
    final encIdentityKey = await _storage.read(
      key: StorageKeys.encryptedIdentityKey,
    );
    final encIdentityIv = await _storage.read(
      key: StorageKeys.encryptedIdentityIv,
    );
    final encTransportKey = await _storage.read(
      key: StorageKeys.encryptedTransportKey,
    );
    final encTransportIv = await _storage.read(
      key: StorageKeys.encryptedTransportIv,
    );
    final pubIdentityKey = await _storage.read(
      key: StorageKeys.publicIdentityKey,
    );
    final pubTransportKey = await _storage.read(
      key: StorageKeys.publicTransportKey,
    );

    if (userId == null ||
        username == null ||
        handle == null ||
        kdfSalt == null ||
        kdfIterationsStr == null ||
        encIdentityKey == null ||
        encIdentityIv == null ||
        encTransportKey == null ||
        encTransportIv == null ||
        pubIdentityKey == null ||
        pubTransportKey == null) {
      return null;
    }

    return UserSession(
      token: token,
      userId: userId,
      username: username,
      handle: handle,
      kdfSalt: kdfSalt,
      kdfIterations: int.parse(kdfIterationsStr),
      encryptedIdentityKey: EncryptedPayload(
        ciphertext: encIdentityKey,
        iv: encIdentityIv,
      ),
      encryptedTransportKey: EncryptedPayload(
        ciphertext: encTransportKey,
        iv: encTransportIv,
      ),
      publicIdentityKey: pubIdentityKey,
      publicTransportKey: pubTransportKey,
    );
  }

  /// Clears the session data.
  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: StorageKeys.authToken),
      _storage.delete(key: StorageKeys.userId),
      _storage.delete(key: StorageKeys.username),
      _storage.delete(key: StorageKeys.userHandle),
      _storage.delete(key: StorageKeys.kdfSalt),
      _storage.delete(key: StorageKeys.kdfIterations),
      _storage.delete(key: StorageKeys.encryptedIdentityKey),
      _storage.delete(key: StorageKeys.encryptedIdentityIv),
      _storage.delete(key: StorageKeys.encryptedTransportKey),
      _storage.delete(key: StorageKeys.encryptedTransportIv),
      _storage.delete(key: StorageKeys.publicIdentityKey),
      _storage.delete(key: StorageKeys.publicTransportKey),
      _storage.delete(key: StorageKeys.masterKey),
    ]);
  }

  // Master key (for "remember password" feature)

  /// Saves the master key for auto-unlock.
  Future<void> saveMasterKey(String base64Key) async {
    await _storage.write(key: StorageKeys.masterKey, value: base64Key);
  }

  /// Gets the saved master key, if any.
  Future<String?> getMasterKey() async {
    return _storage.read(key: StorageKeys.masterKey);
  }

  /// Clears the saved master key.
  Future<void> clearMasterKey() async {
    await _storage.delete(key: StorageKeys.masterKey);
  }

  /// Clears all stored data.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
