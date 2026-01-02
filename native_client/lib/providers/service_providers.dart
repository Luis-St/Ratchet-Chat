import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/server_repository.dart';
import '../data/services/api_service.dart';
import '../data/services/crypto_service.dart';
import '../data/services/opaque_service.dart';
import '../data/services/passkey_service.dart';
import '../data/services/secure_storage_service.dart';

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

/// Provider for the passkey service.
final passkeyServiceProvider = Provider<PasskeyService>((ref) {
  return PasskeyService();
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
    storageService: ref.watch(secureStorageServiceProvider),
    passkeyService: ref.watch(passkeyServiceProvider),
  );
});
