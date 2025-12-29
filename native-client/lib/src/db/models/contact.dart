// Contact model for local database.

import 'dart:typed_data';

/// Represents a contact (another user).
class Contact {
  final String id;
  final String handle;
  final String? displayName;
  final Uint8List? identityPublicKey;
  final Uint8List? transportPublicKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  Contact({
    required this.id,
    required this.handle,
    this.displayName,
    this.identityPublicKey,
    this.transportPublicKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Create from database row.
  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'] as String,
      handle: map['handle'] as String,
      displayName: map['display_name'] as String?,
      identityPublicKey: map['identity_public_key'] as Uint8List?,
      transportPublicKey: map['transport_public_key'] as Uint8List?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  /// Convert to database row.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'handle': handle,
      'display_name': displayName,
      'identity_public_key': identityPublicKey,
      'transport_public_key': transportPublicKey,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Create a copy with updated fields.
  Contact copyWith({
    String? displayName,
    Uint8List? identityPublicKey,
    Uint8List? transportPublicKey,
  }) {
    return Contact(
      id: id,
      handle: handle,
      displayName: displayName ?? this.displayName,
      identityPublicKey: identityPublicKey ?? this.identityPublicKey,
      transportPublicKey: transportPublicKey ?? this.transportPublicKey,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Display name or handle.
  String get name => displayName ?? handle;
}
