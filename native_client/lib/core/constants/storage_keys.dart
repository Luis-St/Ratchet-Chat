/// Keys used for secure storage persistence.
class StorageKeys {
  StorageKeys._();

  // Server configuration
  static const savedServerUrl = 'saved_server_url';
  static const savedServerName = 'saved_server_name';

  // Session data
  static const authToken = 'auth_token';
  static const userId = 'user_id';
  static const username = 'username';
  static const userHandle = 'user_handle';

  // KDF parameters
  static const kdfSalt = 'kdf_salt';
  static const kdfIterations = 'kdf_iterations';

  // Encrypted keys
  static const encryptedIdentityKey = 'encrypted_identity_key';
  static const encryptedIdentityIv = 'encrypted_identity_iv';
  static const encryptedTransportKey = 'encrypted_transport_key';
  static const encryptedTransportIv = 'encrypted_transport_iv';

  // Public keys
  static const publicIdentityKey = 'public_identity_key';
  static const publicTransportKey = 'public_transport_key';

  // Master key (only stored if user opts to save password)
  static const masterKey = 'master_key';
}
