/// Utilities for validating and normalizing server URLs.
class ServerUrlValidator {
  ServerUrlValidator._();

  /// Normalizes a server URL input.
  ///
  /// - Adds https:// prefix if missing (except for localhost which uses http://)
  /// - Removes trailing slashes
  /// - Validates URL format
  ///
  /// Returns null if the URL is invalid.
  static String? normalize(String input) {
    if (input.isEmpty) return null;

    var url = input.trim();

    // Remove trailing slashes
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    // Add protocol if missing
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      // Use http for localhost, https for everything else
      if (_isLocalhost(url)) {
        url = 'http://$url';
      } else {
        url = 'https://$url';
      }
    }

    // Validate URL format
    try {
      final uri = Uri.parse(url);
      if (uri.host.isEmpty) return null;
      if (!uri.hasScheme) return null;
      return url;
    } catch (_) {
      return null;
    }
  }

  /// Checks if the URL points to localhost.
  static bool _isLocalhost(String url) {
    final lower = url.toLowerCase();
    return lower.startsWith('localhost') ||
        lower.startsWith('127.0.0.1') ||
        lower.startsWith('[::1]');
  }

  /// Validates a URL format without normalization.
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Extracts the display name from a URL (host + port if non-standard).
  static String getDisplayName(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.hasPort && uri.port != 80 && uri.port != 443) {
        return '${uri.host}:${uri.port}';
      }
      return uri.host;
    } catch (_) {
      return url;
    }
  }

  /// Gets the federation endpoint URL for server validation.
  static String getFederationUrl(String baseUrl) {
    return '$baseUrl/.well-known/ratchet-chat/federation.json';
  }
}
