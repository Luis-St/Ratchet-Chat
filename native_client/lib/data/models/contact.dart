import 'package:flutter/foundation.dart';

/// A contact with their public keys for E2E encrypted messaging.
@immutable
class Contact {
  const Contact({
    required this.handle,
    required this.username,
    required this.host,
    required this.publicIdentityKey,
    required this.publicTransportKey,
    required this.createdAt,
    this.nickname,
    this.displayName,
    this.avatarFilename,
  });

  /// Full handle (username@host) - primary identifier.
  final String handle;

  /// Username portion of the handle.
  final String username;

  /// Server host portion of the handle.
  final String host;

  /// Custom nickname set by the user.
  final String? nickname;

  /// Public identity key for signature verification (ML-DSA-65, base64).
  final String publicIdentityKey;

  /// Public transport key for message encryption (ML-KEM-768, base64).
  final String publicTransportKey;

  /// Display name from directory lookup.
  final String? displayName;

  /// Avatar filename from directory lookup.
  final String? avatarFilename;

  /// When the contact was added.
  final DateTime createdAt;

  /// Returns the best display name: nickname > displayName > username.
  String get effectiveDisplayName => nickname ?? displayName ?? username;

  /// Creates a Contact from JSON map.
  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      handle: json['handle'] as String,
      username: json['username'] as String,
      host: json['host'] as String,
      nickname: json['nickname'] as String?,
      publicIdentityKey: json['publicIdentityKey'] as String,
      publicTransportKey: json['publicTransportKey'] as String,
      displayName: json['displayName'] as String?,
      avatarFilename: json['avatarFilename'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Converts the Contact to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'handle': handle,
      'username': username,
      'host': host,
      'nickname': nickname,
      'publicIdentityKey': publicIdentityKey,
      'publicTransportKey': publicTransportKey,
      'displayName': displayName,
      'avatarFilename': avatarFilename,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Creates a copy with the given fields replaced.
  Contact copyWith({
    String? handle,
    String? username,
    String? host,
    String? nickname,
    String? publicIdentityKey,
    String? publicTransportKey,
    String? displayName,
    String? avatarFilename,
    DateTime? createdAt,
  }) {
    return Contact(
      handle: handle ?? this.handle,
      username: username ?? this.username,
      host: host ?? this.host,
      nickname: nickname ?? this.nickname,
      publicIdentityKey: publicIdentityKey ?? this.publicIdentityKey,
      publicTransportKey: publicTransportKey ?? this.publicTransportKey,
      displayName: displayName ?? this.displayName,
      avatarFilename: avatarFilename ?? this.avatarFilename,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Contact &&
          runtimeType == other.runtimeType &&
          handle.toLowerCase() == other.handle.toLowerCase();

  @override
  int get hashCode => handle.toLowerCase().hashCode;

  @override
  String toString() =>
      'Contact(handle: $handle, displayName: $effectiveDisplayName)';
}
