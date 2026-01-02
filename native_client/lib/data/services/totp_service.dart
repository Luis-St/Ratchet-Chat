import 'dart:typed_data';

import 'package:base32/base32.dart';
import 'package:pointycastle/export.dart';

/// Service for TOTP (Time-based One-Time Password) operations.
///
/// Implements RFC 6238 TOTP using HMAC-SHA1.
class TotpService {
  /// Generates a 160-bit (20 byte) TOTP secret encoded as Base32.
  ///
  /// This matches the web client's TOTP secret generation.
  String generateSecret() {
    final secretBytes = _generateSecureRandom(20);
    return base32.encode(secretBytes);
  }

  /// Generates an otpauth:// URI for QR code scanning.
  ///
  /// The URI follows the Google Authenticator format:
  /// otpauth://totp/ISSUER:USERNAME?secret=SECRET&issuer=ISSUER&algorithm=SHA1&digits=6&period=30
  String getTotpUri({
    required String secret,
    required String username,
    required String issuer,
  }) {
    final encodedIssuer = Uri.encodeComponent(issuer);
    final encodedUsername = Uri.encodeComponent(username);
    final label = '$encodedIssuer:$encodedUsername';

    return 'otpauth://totp/$label?secret=$secret&issuer=$encodedIssuer&algorithm=SHA1&digits=6&period=30';
  }

  /// Generates the current 6-digit TOTP code.
  ///
  /// Uses HMAC-SHA1 per RFC 6238.
  String generateCode(String secret) {
    final secretBytes = base32.decode(secret);
    final timeStep = DateTime.now().millisecondsSinceEpoch ~/ 30000;

    // Convert time step to 8-byte big-endian
    final timeBytes = Uint8List(8);
    var t = timeStep;
    for (var i = 7; i >= 0; i--) {
      timeBytes[i] = t & 0xff;
      t >>= 8;
    }

    // HMAC-SHA1
    final hmac = HMac(SHA1Digest(), 64);
    hmac.init(KeyParameter(Uint8List.fromList(secretBytes)));
    final hash = hmac.process(timeBytes);

    // Dynamic truncation (RFC 4226)
    final offset = hash[hash.length - 1] & 0x0f;
    final code = ((hash[offset] & 0x7f) << 24) |
                 ((hash[offset + 1] & 0xff) << 16) |
                 ((hash[offset + 2] & 0xff) << 8) |
                 (hash[offset + 3] & 0xff);

    final otp = code % 1000000;
    return otp.toString().padLeft(6, '0');
  }

  /// Normalizes a recovery code by removing dashes and converting to uppercase.
  String normalizeRecoveryCode(String code) {
    return code.replaceAll('-', '').toUpperCase();
  }

  Uint8List _generateSecureRandom(int length) {
    final random = FortunaRandom();
    random.seed(
      KeyParameter(
        Uint8List.fromList(
          List<int>.generate(
            32,
            (i) => DateTime.now().microsecondsSinceEpoch + i,
          ),
        ),
      ),
    );
    return random.nextBytes(length);
  }
}
