import 'package:flutter/foundation.dart';

/// Represents the current authentication state of the app.
enum AuthStatus {
  /// App is initializing, checking for existing session.
  loading,

  /// No active session, user needs to login or register.
  guest,

  /// Session exists but master key is not available (password not saved).
  /// User must enter password to unlock and decrypt keys.
  locked,

  /// Fully authenticated with decrypted keys available.
  authenticated,
}

/// Full authentication state including user information.
@immutable
class AuthState {
  const AuthState({
    required this.status,
    this.userId,
    this.username,
    this.handle,
    this.error,
  });

  const AuthState.loading() : this(status: AuthStatus.loading);

  const AuthState.guest({String? error})
    : this(status: AuthStatus.guest, error: error);

  const AuthState.locked({
    required String userId,
    required String username,
    String? handle,
  }) : this(
         status: AuthStatus.locked,
         userId: userId,
         username: username,
         handle: handle,
       );

  const AuthState.authenticated({
    required String userId,
    required String username,
    String? handle,
  }) : this(
         status: AuthStatus.authenticated,
         userId: userId,
         username: username,
         handle: handle,
       );

  final AuthStatus status;
  final String? userId;
  final String? username;
  final String? handle;
  final String? error;

  bool get isLoading => status == AuthStatus.loading;

  bool get isGuest => status == AuthStatus.guest;

  bool get isLocked => status == AuthStatus.locked;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? username,
    String? handle,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      handle: handle ?? this.handle,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          userId == other.userId &&
          username == other.username &&
          handle == other.handle &&
          error == other.error;

  @override
  int get hashCode => Object.hash(status, userId, username, handle, error);

  @override
  String toString() =>
      'AuthState(status: $status, userId: $userId, username: $username, handle: $handle, error: $error)';
}
