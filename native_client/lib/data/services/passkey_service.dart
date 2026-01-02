import 'dart:io' show Platform;

import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';

import '../../core/errors/auth_exceptions.dart';

/// Service for passkey (WebAuthn/FIDO2) operations.
///
/// Wraps the passkeys package and provides platform detection.
/// Returns false for Linux as it doesn't support passkeys.
class PasskeyService {
  PasskeyService() : _authenticator = PasskeyAuthenticator();

  final PasskeyAuthenticator _authenticator;

  /// Checks if passkeys are supported on the current platform.
  ///
  /// Returns false on Linux, true on iOS, Android, macOS, and Windows.
  bool get isSupported {
    if (Platform.isLinux) {
      return false;
    }
    // iOS, Android, macOS, Windows are supported
    return Platform.isIOS ||
        Platform.isAndroid ||
        Platform.isMacOS ||
        Platform.isWindows;
  }

  /// Creates a passkey credential during registration.
  ///
  /// Takes the WebAuthn creation options from the server and returns
  /// the registration response to send back to the server.
  ///
  /// Throws [PasskeyNotSupportedException] if called on unsupported platform.
  /// Throws [PasskeyCancelledException] if user cancels the operation.
  /// Throws [PasskeyException] for other errors.
  Future<RegisterResponseType> createCredential({
    required String relyingPartyId,
    required String relyingPartyName,
    required String userId,
    required String userName,
    required String userDisplayName,
    required String challenge,
    List<String>? excludeCredentialIds,
  }) async {
    if (!isSupported) {
      throw const PasskeyNotSupportedException();
    }

    try {
      final request = RegisterRequestType(
        challenge: challenge,
        relyingParty: RelyingPartyType(
          name: relyingPartyName,
          id: relyingPartyId,
        ),
        user: UserType(
          id: userId,
          name: userName,
          displayName: userDisplayName,
        ),
        authSelectionType: AuthenticatorSelectionType(
          authenticatorAttachment: 'platform',
          residentKey: 'preferred',
          requireResidentKey: false,
          userVerification: 'preferred',
        ),
        pubKeyCredParams: [
          PubKeyCredParamType(alg: -7, type: 'public-key'), // ES256
          PubKeyCredParamType(alg: -257, type: 'public-key'), // RS256
        ],
        timeout: 60000,
        attestation: 'none',
        excludeCredentials: excludeCredentialIds
            ?.map(
              (id) => CredentialType(
                type: 'public-key',
                id: id,
                transports: ['internal', 'hybrid'],
              ),
            )
            .toList() ?? [],
      );

      return await _authenticator.register(request);
    } on PasskeyAuthCancelledException {
      throw const PasskeyCancelledException();
    } catch (e) {
      throw PasskeyException('Failed to create passkey: $e');
    }
  }

  /// Authenticates with an existing passkey.
  ///
  /// Takes the WebAuthn assertion options from the server and returns
  /// the authentication response to send back to the server.
  ///
  /// Throws [PasskeyNotSupportedException] if called on unsupported platform.
  /// Throws [PasskeyCancelledException] if user cancels the operation.
  /// Throws [PasskeyException] for other errors.
  Future<AuthenticateResponseType> authenticate({
    required String relyingPartyId,
    required String challenge,
    List<CredentialType>? allowCredentials,
  }) async {
    if (!isSupported) {
      throw const PasskeyNotSupportedException();
    }

    try {
      final request = AuthenticateRequestType(
        relyingPartyId: relyingPartyId,
        challenge: challenge,
        timeout: 60000,
        userVerification: 'preferred',
        allowCredentials: allowCredentials,
        mediation: MediationType.Optional,
        preferImmediatelyAvailableCredentials: true,
      );

      return await _authenticator.authenticate(request);
    } on PasskeyAuthCancelledException {
      throw const PasskeyCancelledException();
    } catch (e) {
      throw PasskeyException('Failed to authenticate with passkey: $e');
    }
  }
}
