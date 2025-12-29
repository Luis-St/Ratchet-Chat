// Authentication API endpoints.

import 'api_client.dart';

/// OPAQUE registration initialization response.
class RegistrationInitResponse {
  final String evaluation;
  final String serverPublicKey;

  RegistrationInitResponse({
    required this.evaluation,
    required this.serverPublicKey,
  });

  factory RegistrationInitResponse.fromJson(Map<String, dynamic> json) {
    return RegistrationInitResponse(
      evaluation: json['evaluation'] as String,
      serverPublicKey: json['serverPublicKey'] as String,
    );
  }
}

/// OPAQUE registration finish response.
class RegistrationFinishResponse {
  final String userId;
  final String handle;

  RegistrationFinishResponse({
    required this.userId,
    required this.handle,
  });

  factory RegistrationFinishResponse.fromJson(Map<String, dynamic> json) {
    return RegistrationFinishResponse(
      userId: json['userId'] as String,
      handle: json['handle'] as String,
    );
  }
}

/// OPAQUE login initialization response (KE2).
class LoginInitResponse {
  final String credentialResponse;
  final String serverNonce;
  final String serverKeyshare;
  final String serverMac;

  LoginInitResponse({
    required this.credentialResponse,
    required this.serverNonce,
    required this.serverKeyshare,
    required this.serverMac,
  });

  factory LoginInitResponse.fromJson(Map<String, dynamic> json) {
    return LoginInitResponse(
      credentialResponse: json['credentialResponse'] as String,
      serverNonce: json['serverNonce'] as String,
      serverKeyshare: json['serverKeyshare'] as String,
      serverMac: json['serverMac'] as String,
    );
  }
}

/// OPAQUE login finish response.
class LoginFinishResponse {
  final String token;
  final String userId;
  final String handle;
  final UserSettings settings;

  LoginFinishResponse({
    required this.token,
    required this.userId,
    required this.handle,
    required this.settings,
  });

  factory LoginFinishResponse.fromJson(Map<String, dynamic> json) {
    return LoginFinishResponse(
      token: json['token'] as String,
      userId: json['userId'] as String,
      handle: json['handle'] as String,
      settings: UserSettings.fromJson(json['settings'] as Map<String, dynamic>),
    );
  }
}

/// User settings.
class UserSettings {
  final String? identityPublicKey;
  final String? transportPublicKey;

  UserSettings({
    this.identityPublicKey,
    this.transportPublicKey,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      identityPublicKey: json['identityPublicKey'] as String?,
      transportPublicKey: json['transportPublicKey'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (identityPublicKey != null) 'identityPublicKey': identityPublicKey,
      if (transportPublicKey != null) 'transportPublicKey': transportPublicKey,
    };
  }
}

/// Current user info.
class CurrentUser {
  final String userId;
  final String handle;
  final UserSettings settings;

  CurrentUser({
    required this.userId,
    required this.handle,
    required this.settings,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      userId: json['userId'] as String,
      handle: json['handle'] as String,
      settings: UserSettings.fromJson(json['settings'] as Map<String, dynamic>),
    );
  }
}

/// Passkey registration options.
class PasskeyRegistrationOptions {
  final Map<String, dynamic> options;

  PasskeyRegistrationOptions({required this.options});

  factory PasskeyRegistrationOptions.fromJson(dynamic json) {
    return PasskeyRegistrationOptions(options: json as Map<String, dynamic>);
  }
}

/// Passkey login options.
class PasskeyLoginOptions {
  final Map<String, dynamic> options;

  PasskeyLoginOptions({required this.options});

  factory PasskeyLoginOptions.fromJson(dynamic json) {
    return PasskeyLoginOptions(options: json as Map<String, dynamic>);
  }
}

/// Authentication API.
class AuthApi {
  final ApiClient _client;

  AuthApi(this._client);

  // ============== OPAQUE Registration ==============

  /// Start OPAQUE registration.
  Future<RegistrationInitResponse> registerInit({
    required String handle,
    required String registrationRequest,
  }) async {
    final response = await _client.post<RegistrationInitResponse>(
      '/auth/register/init',
      (json) => RegistrationInitResponse.fromJson(json as Map<String, dynamic>),
      body: {
        'handle': handle,
        'registrationRequest': registrationRequest,
      },
      includeAuth: false,
    );
    return response.data;
  }

  /// Finish OPAQUE registration.
  Future<RegistrationFinishResponse> registerFinish({
    required String handle,
    required String registrationRecord,
    required String identityPublicKey,
    required String transportPublicKey,
  }) async {
    final response = await _client.post<RegistrationFinishResponse>(
      '/auth/register/finish',
      (json) => RegistrationFinishResponse.fromJson(json as Map<String, dynamic>),
      body: {
        'handle': handle,
        'registrationRecord': registrationRecord,
        'identityPublicKey': identityPublicKey,
        'transportPublicKey': transportPublicKey,
      },
      includeAuth: false,
    );
    return response.data;
  }

  // ============== OPAQUE Login ==============

  /// Start OPAQUE login (sends KE1, receives KE2).
  Future<LoginInitResponse> loginInit({
    required String handle,
    required String ke1,
  }) async {
    final response = await _client.post<LoginInitResponse>(
      '/auth/login/init',
      (json) => LoginInitResponse.fromJson(json as Map<String, dynamic>),
      body: {
        'handle': handle,
        'ke1': ke1,
      },
      includeAuth: false,
    );
    return response.data;
  }

  /// Finish OPAQUE login (sends KE3, receives session).
  Future<LoginFinishResponse> loginFinish({
    required String handle,
    required String ke3,
  }) async {
    final response = await _client.post<LoginFinishResponse>(
      '/auth/login/finish',
      (json) => LoginFinishResponse.fromJson(json as Map<String, dynamic>),
      body: {
        'handle': handle,
        'ke3': ke3,
      },
      includeAuth: false,
    );
    return response.data;
  }

  // ============== Passkeys ==============

  /// Get passkey registration options.
  Future<PasskeyRegistrationOptions> getPasskeyRegisterOptions() async {
    final response = await _client.post<PasskeyRegistrationOptions>(
      '/auth/passkey/register/options',
      (json) => PasskeyRegistrationOptions.fromJson(json),
      includeAuth: true,
    );
    return response.data;
  }

  /// Verify passkey registration.
  Future<void> verifyPasskeyRegistration({
    required Map<String, dynamic> credential,
  }) async {
    await _client.post<void>(
      '/auth/passkey/register/verify',
      (_) {},
      body: credential,
      includeAuth: true,
    );
  }

  /// Get passkey login options.
  Future<PasskeyLoginOptions> getPasskeyLoginOptions({
    required String handle,
  }) async {
    final response = await _client.post<PasskeyLoginOptions>(
      '/auth/passkey/login/options',
      (json) => PasskeyLoginOptions.fromJson(json),
      body: {'handle': handle},
      includeAuth: false,
    );
    return response.data;
  }

  /// Verify passkey login.
  Future<LoginFinishResponse> verifyPasskeyLogin({
    required String handle,
    required Map<String, dynamic> credential,
  }) async {
    final response = await _client.post<LoginFinishResponse>(
      '/auth/passkey/login/verify',
      (json) => LoginFinishResponse.fromJson(json as Map<String, dynamic>),
      body: {
        'handle': handle,
        'credential': credential,
      },
      includeAuth: false,
    );
    return response.data;
  }

  // ============== Session ==============

  /// Get current user info.
  Future<CurrentUser> getCurrentUser() async {
    final response = await _client.get<CurrentUser>(
      '/auth/me',
      (json) => CurrentUser.fromJson(json as Map<String, dynamic>),
      includeAuth: true,
    );
    return response.data;
  }

  /// Update user settings.
  Future<void> updateSettings(UserSettings settings) async {
    await _client.put<void>(
      '/auth/settings',
      (_) {},
      body: settings.toJson(),
      includeAuth: true,
    );
  }

  /// Logout.
  Future<void> logout() async {
    await _client.post<void>(
      '/auth/logout',
      (_) {},
      includeAuth: true,
    );
  }
}
