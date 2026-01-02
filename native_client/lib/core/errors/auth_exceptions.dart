/// Base class for all authentication-related exceptions.
sealed class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when server URL is invalid or unreachable.
class InvalidServerException extends AuthException {
  const InvalidServerException([
    String message = 'Invalid or unreachable server',
  ]) : super(message);
}

/// Thrown when server is not a valid Ratchet Chat instance.
class NotRatchetServerException extends AuthException {
  const NotRatchetServerException([
    String message = 'Not a valid Ratchet Chat server',
  ]) : super(message);
}

/// Thrown when login credentials are invalid.
class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException([
    String message = 'Invalid username or password',
  ]) : super(message);
}

/// Thrown when user is not found.
class UserNotFoundException extends AuthException {
  const UserNotFoundException([String message = 'User not found'])
    : super(message);
}

/// Thrown when rate limited by the server.
class RateLimitedException extends AuthException {
  const RateLimitedException({
    required this.retryAfterSeconds,
    String message = 'Too many attempts',
  }) : super(message);

  final int retryAfterSeconds;
}

/// Thrown when there's a network error.
class NetworkException extends AuthException {
  const NetworkException([String message = 'Network error']) : super(message);
}

/// Thrown when the server returns an unexpected error.
class ServerException extends AuthException {
  const ServerException([String message = 'Server error']) : super(message);

  factory ServerException.fromStatusCode(int statusCode) {
    return ServerException('Server error: $statusCode');
  }
}

/// Thrown when session has expired or is invalid.
class SessionExpiredException extends AuthException {
  const SessionExpiredException([String message = 'Session expired'])
    : super(message);
}

/// Thrown when master key decryption fails (wrong password).
class DecryptionException extends AuthException {
  const DecryptionException([String message = 'Failed to decrypt keys'])
    : super(message);
}

/// Thrown when username is already taken during registration.
class UsernameTakenException extends AuthException {
  const UsernameTakenException([String message = 'Username already taken'])
    : super(message);
}

/// Thrown when username format is invalid.
class InvalidUsernameException extends AuthException {
  const InvalidUsernameException([String message = 'Invalid username format'])
    : super(message);
}

/// Thrown when passkey operation is cancelled by the user.
class PasskeyCancelledException extends AuthException {
  const PasskeyCancelledException([
    String message = 'Passkey authentication was cancelled',
  ]) : super(message);
}

/// Thrown when passkeys are not supported on the current platform.
class PasskeyNotSupportedException extends AuthException {
  const PasskeyNotSupportedException([
    String message = 'Passkeys are not supported on this platform',
  ]) : super(message);
}

/// Thrown when a passkey operation fails.
class PasskeyException extends AuthException {
  const PasskeyException([String message = 'Passkey operation failed'])
    : super(message);
}

/// Thrown when 2FA is required to complete login.
class TwoFactorRequiredException extends AuthException {
  const TwoFactorRequiredException({
    required this.sessionTicket,
    String message = 'Two-factor authentication required',
  }) : super(message);

  final String sessionTicket;
}

/// Thrown when TOTP code is invalid.
class InvalidTotpCodeException extends AuthException {
  const InvalidTotpCodeException([String message = 'Invalid verification code'])
    : super(message);
}

/// Thrown when recovery code is invalid.
class InvalidRecoveryCodeException extends AuthException {
  const InvalidRecoveryCodeException([
    String message = 'Invalid recovery code',
  ]) : super(message);
}

/// Thrown when session ticket has expired.
class SessionTicketExpiredException extends AuthException {
  const SessionTicketExpiredException([
    String message = 'Session expired, please try again',
  ]) : super(message);
}

/// Thrown when too many 2FA attempts have been made.
class TooManyAttemptsException extends AuthException {
  const TooManyAttemptsException([
    String message = 'Too many attempts, please try again later',
  ]) : super(message);
}
