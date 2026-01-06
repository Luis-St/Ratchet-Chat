import '../../core/errors/auth_exceptions.dart';
import 'api_service.dart';

/// Result of a directory lookup.
class DirectoryLookupResult {
  const DirectoryLookupResult({
    required this.handle,
    required this.host,
    required this.publicIdentityKey,
    required this.publicTransportKey,
    this.displayName,
    this.avatarFilename,
  });

  final String handle;
  final String host;
  final String publicIdentityKey;
  final String publicTransportKey;
  final String? displayName;
  final String? avatarFilename;
}

/// Service for looking up users in the directory.
class DirectoryService {
  DirectoryService({required ApiService apiService}) : _apiService = apiService;

  final ApiService _apiService;

  /// Looks up a user by handle in the directory.
  ///
  /// Returns the user's public keys and optional display info.
  /// Throws [ContactNotFoundException] if user not found.
  /// Throws [InvalidHandleException] if handle format is invalid.
  /// Throws [DirectoryLookupException] for other lookup failures.
  Future<DirectoryLookupResult> lookupHandle(String handle) async {
    final normalized = _normalizeHandle(handle);

    // Validate handle format
    if (!_isValidHandle(normalized)) {
      throw const InvalidHandleException();
    }

    try {
      final encoded = Uri.encodeComponent(normalized);
      final response = await _apiService.get(
        '/api/directory?handle=$encoded',
        includeAuth: false,
      );

      final resultHandle = response['handle'] as String? ?? normalized;
      final host = response['host'] as String? ?? _extractHost(resultHandle);

      return DirectoryLookupResult(
        handle: resultHandle,
        host: host,
        publicIdentityKey: response['public_identity_key'] as String,
        publicTransportKey: response['public_transport_key'] as String,
        displayName: response['display_name'] as String?,
        avatarFilename: response['avatar_filename'] as String?,
      );
    } on UserNotFoundException {
      throw const ContactNotFoundException();
    } on NetworkException {
      rethrow;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw DirectoryLookupException('Failed to lookup user: $e');
    }
  }

  /// Normalizes a handle to lowercase and adds instance host if missing.
  String _normalizeHandle(String handle) {
    final trimmed = handle.trim().toLowerCase();

    // If handle already contains @, return as-is
    if (trimmed.contains('@')) {
      return trimmed;
    }

    // Add instance host if not present
    final baseUrl = _apiService.baseUrl;
    if (baseUrl != null) {
      final host = _extractHostFromUrl(baseUrl);
      if (host != null) {
        return '$trimmed@$host';
      }
    }

    return trimmed;
  }

  /// Validates handle format (username@host).
  bool _isValidHandle(String handle) {
    final atIndex = handle.lastIndexOf('@');
    if (atIndex <= 0) return false;

    final username = handle.substring(0, atIndex);
    final host = handle.substring(atIndex + 1);

    if (username.isEmpty || host.isEmpty) return false;

    // Basic host validation (alphanumeric, dots, hyphens, optional port)
    final hostPattern = RegExp(r'^[a-zA-Z0-9.-]+(?::\d+)?$');
    return hostPattern.hasMatch(host);
  }

  /// Extracts host from a handle.
  String _extractHost(String handle) {
    final atIndex = handle.lastIndexOf('@');
    if (atIndex <= 0) return '';
    return handle.substring(atIndex + 1);
  }

  /// Extracts host from a URL.
  String? _extractHostFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.port != 80 && uri.port != 443 && uri.port != 0) {
        return '${uri.host}:${uri.port}';
      }
      return uri.host;
    } catch (_) {
      return null;
    }
  }

  /// Parses a handle into username and host parts.
  /// Returns null if handle format is invalid.
  static ({String username, String host})? parseHandle(String handle) {
    final normalized = handle.trim().toLowerCase();
    final atIndex = normalized.lastIndexOf('@');

    if (atIndex <= 0) return null;

    final username = normalized.substring(0, atIndex);
    final host = normalized.substring(atIndex + 1);

    if (username.isEmpty || host.isEmpty) return null;

    return (username: username, host: host);
  }
}
