import 'package:flutter/foundation.dart';

/// KDF (Key Derivation Function) parameters for a user.
@immutable
class KdfParams {
  const KdfParams({required this.salt, required this.iterations});

  /// Salt for key derivation (base64 encoded).
  final String salt;

  /// Number of iterations for PBKDF2.
  final int iterations;

  factory KdfParams.fromJson(Map<String, dynamic> json) {
    return KdfParams(
      salt: json['kdf_salt'] as String,
      iterations: json['kdf_iterations'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KdfParams &&
          runtimeType == other.runtimeType &&
          salt == other.salt &&
          iterations == other.iterations;

  @override
  int get hashCode => Object.hash(salt, iterations);

  @override
  String toString() => 'KdfParams(salt: $salt, iterations: $iterations)';
}
