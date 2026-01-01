import '../../core/utils/server_url_validator.dart';
import '../models/server_config.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';

/// Result of server validation.
class ServerValidationResult {
  const ServerValidationResult({
    required this.isValid,
    this.serverName,
    this.error,
  });

  final bool isValid;
  final String? serverName;
  final String? error;
}

/// Repository for managing server configuration.
class ServerRepository {
  ServerRepository({
    required SecureStorageService storageService,
    required ApiService apiService,
  }) : _storageService = storageService,
       _apiService = apiService;

  final SecureStorageService _storageService;
  final ApiService _apiService;

  /// Validates that a URL points to a valid Ratchet Chat server.
  Future<ServerValidationResult> validateServer(String url) async {
    // Normalize the URL
    final normalizedUrl = ServerUrlValidator.normalize(url);
    if (normalizedUrl == null) {
      return const ServerValidationResult(
        isValid: false,
        error: 'Invalid URL format',
      );
    }

    // Check if server responds with federation info
    final isValid = await _apiService.validateServer(normalizedUrl);
    if (!isValid) {
      return const ServerValidationResult(
        isValid: false,
        error: 'Not a valid Ratchet Chat server',
      );
    }

    // Extract server name from URL
    final serverName = ServerUrlValidator.getDisplayName(normalizedUrl);

    return ServerValidationResult(isValid: true, serverName: serverName);
  }

  /// Saves the server configuration.
  Future<void> saveServer(ServerConfig config) async {
    await _storageService.saveServer(config);
  }

  /// Gets the saved server configuration, if any.
  Future<ServerConfig?> getSavedServer() async {
    return _storageService.getSavedServer();
  }

  /// Clears the saved server configuration.
  Future<void> clearSavedServer() async {
    await _storageService.clearSavedServer();
  }

  /// Gets the normalized URL for a given input.
  String? normalizeUrl(String input) {
    return ServerUrlValidator.normalize(input);
  }
}
