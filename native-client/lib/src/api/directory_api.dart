// Directory API endpoints.

import 'api_client.dart';

/// User lookup result.
class UserLookup {
  final String userId;
  final String handle;
  final String identityPublicKey;
  final String transportPublicKey;
  final bool isFederated;
  final String? federatedServer;

  UserLookup({
    required this.userId,
    required this.handle,
    required this.identityPublicKey,
    required this.transportPublicKey,
    this.isFederated = false,
    this.federatedServer,
  });

  factory UserLookup.fromJson(Map<String, dynamic> json) {
    return UserLookup(
      userId: json['userId'] as String,
      handle: json['handle'] as String,
      identityPublicKey: json['identityPublicKey'] as String,
      transportPublicKey: json['transportPublicKey'] as String,
      isFederated: json['isFederated'] as bool? ?? false,
      federatedServer: json['federatedServer'] as String?,
    );
  }
}

/// Directory API.
class DirectoryApi {
  final ApiClient _client;

  DirectoryApi(this._client);

  /// Lookup a user by handle.
  ///
  /// The handle can be local (username) or federated (username@server).
  Future<UserLookup> lookupUser(String handle) async {
    // URL encode the handle in case it contains special characters
    final encodedHandle = Uri.encodeComponent(handle);

    final response = await _client.get<UserLookup>(
      '/directory/lookup/$encodedHandle',
      (json) => UserLookup.fromJson(json as Map<String, dynamic>),
      includeAuth: true,
    );
    return response.data;
  }

  /// Check if a handle is available for registration.
  Future<bool> isHandleAvailable(String handle) async {
    try {
      await lookupUser(handle);
      return false; // User exists, handle not available
    } catch (e) {
      if (e is ApiError && e.isNotFound) {
        return true; // User not found, handle is available
      }
      rethrow;
    }
  }
}
