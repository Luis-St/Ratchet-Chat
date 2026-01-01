import 'package:flutter/foundation.dart';

/// Configuration for a Ratchet Chat server.
@immutable
class ServerConfig {
  const ServerConfig({required this.url, this.name, this.isSaved = false});

  /// The full URL of the server (e.g., "https://chat.example.com").
  final String url;

  /// Optional display name for the server.
  final String? name;

  /// Whether this server configuration is saved for future use.
  final bool isSaved;

  /// Returns the display name, falling back to the host from the URL.
  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
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

  ServerConfig copyWith({String? url, String? name, bool? isSaved}) {
    return ServerConfig(
      url: url ?? this.url,
      name: name ?? this.name,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerConfig &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          name == other.name &&
          isSaved == other.isSaved;

  @override
  int get hashCode => Object.hash(url, name, isSaved);

  @override
  String toString() =>
      'ServerConfig(url: $url, name: $name, isSaved: $isSaved)';
}
