import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/contacts_repository.dart';
import '../data/repositories/message_repository.dart';
import '../data/repositories/server_repository.dart';
import '../data/services/api_service.dart';
import '../data/services/crypto_service.dart';
import '../data/services/directory_service.dart';
import '../data/services/message_crypto_service.dart';
import '../data/services/message_service.dart';
import '../data/services/opaque_service.dart';
import '../data/services/passkey_service.dart';
import '../data/services/pq_crypto_service.dart';
import '../data/services/secure_storage_service.dart';
import '../data/services/socket_service.dart';
import '../data/services/totp_service.dart';

/// Provider for the secure storage service.
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Provider for the API service.
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

/// Provider for the OPAQUE service.
final opaqueServiceProvider = Provider<OpaqueService>((ref) {
  return OpaqueService();
});

/// Provider for the crypto service.
final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return CryptoService();
});

/// Provider for the post-quantum crypto service.
final pqCryptoServiceProvider = Provider<PqCryptoService>((ref) {
  return PqCryptoService();
});

/// Provider for the passkey service.
final passkeyServiceProvider = Provider<PasskeyService>((ref) {
  return PasskeyService();
});

/// Provider for the TOTP service.
final totpServiceProvider = Provider<TotpService>((ref) {
  return TotpService();
});

/// Provider for the server repository.
final serverRepositoryProvider = Provider<ServerRepository>((ref) {
  return ServerRepository(
    storageService: ref.watch(secureStorageServiceProvider),
    apiService: ref.watch(apiServiceProvider),
  );
});

/// Provider for the auth repository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiService: ref.watch(apiServiceProvider),
    opaqueService: ref.watch(opaqueServiceProvider),
    cryptoService: ref.watch(cryptoServiceProvider),
    pqCryptoService: ref.watch(pqCryptoServiceProvider),
    storageService: ref.watch(secureStorageServiceProvider),
    passkeyService: ref.watch(passkeyServiceProvider),
    totpService: ref.watch(totpServiceProvider),
  );
});

/// Provider for the directory service.
final directoryServiceProvider = Provider<DirectoryService>((ref) {
  return DirectoryService(
    apiService: ref.watch(apiServiceProvider),
  );
});

/// Provider for the contacts repository.
final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  return ContactsRepository(
    apiService: ref.watch(apiServiceProvider),
    cryptoService: ref.watch(cryptoServiceProvider),
    storageService: ref.watch(secureStorageServiceProvider),
    directoryService: ref.watch(directoryServiceProvider),
  );
});

/// Provider for the app database (Drift).
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Provider for the socket service.
final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for the message crypto service.
final messageCryptoServiceProvider = Provider<MessageCryptoService>((ref) {
  return MessageCryptoService(
    pqCrypto: ref.watch(pqCryptoServiceProvider),
    crypto: ref.watch(cryptoServiceProvider),
  );
});

/// Provider for the message service.
final messageServiceProvider = Provider<MessageService>((ref) {
  return MessageService(
    api: ref.watch(apiServiceProvider),
  );
});

/// Provider for the message repository.
final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(
    db: ref.watch(appDatabaseProvider),
    messageService: ref.watch(messageServiceProvider),
    messageCrypto: ref.watch(messageCryptoServiceProvider),
  );
});
