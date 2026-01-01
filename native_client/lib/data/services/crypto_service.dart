import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../models/user_session.dart';

/// Service for cryptographic operations.
class CryptoService {
  /// Derives a master key from password using PBKDF2.
  ///
  /// This matches the web client's key derivation.
  Uint8List deriveMasterKey({
    required String password,
    required String saltBase64,
    required int iterations,
  }) {
    final salt = base64Decode(saltBase64);
    final passwordBytes = utf8.encode(password);

    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(salt, iterations, 32));

    return pbkdf2.process(Uint8List.fromList(passwordBytes));
  }

  /// Encrypts data using AES-GCM.
  EncryptedPayload encrypt(Uint8List data, Uint8List key) {
    final iv = _generateSecureRandom(12);

    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      true,
      AEADParameters(
        KeyParameter(key),
        128, // tag length in bits
        iv,
        Uint8List(0),
      ),
    );

    final ciphertext = cipher.process(data);

    return EncryptedPayload(
      ciphertext: base64Encode(ciphertext),
      iv: base64Encode(iv),
    );
  }

  /// Decrypts data using AES-GCM.
  Uint8List decrypt(EncryptedPayload payload, Uint8List key) {
    final ciphertext = base64Decode(payload.ciphertext);
    final iv = base64Decode(payload.iv);

    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      false,
      AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)),
    );

    return cipher.process(Uint8List.fromList(ciphertext));
  }

  /// Exports a key to base64 for storage.
  String exportKey(Uint8List key) {
    return base64Encode(key);
  }

  /// Imports a key from base64.
  Uint8List importKey(String base64Key) {
    return base64Decode(base64Key);
  }

  /// Generates random bytes for salt.
  Uint8List generateSalt([int length = 32]) {
    return _generateSecureRandom(length);
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
