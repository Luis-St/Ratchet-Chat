import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ratchet_chat/src/crypto/aes_gcm.dart';

void main() {
  group('AES-GCM Encryption', () {
    test('encrypt produces output with nonce prepended', () {
      final key = AesGcm.generateKey();
      final plaintext = Uint8List.fromList(utf8.encode('Hello, World!'));

      final ciphertext = AesGcm.encrypt(plaintext, key);

      // Output should be: nonce (12) + encrypted data + tag (16)
      expect(ciphertext.length, greaterThan(AesGcm.nonceLength + AesGcm.tagLength));
      // First 12 bytes are the nonce
      expect(ciphertext.length, equals(AesGcm.nonceLength + plaintext.length + AesGcm.tagLength));
    });

    test('encrypt/decrypt roundtrip works', () {
      final key = AesGcm.generateKey();
      final plaintext = Uint8List.fromList(utf8.encode('Secret message for testing'));

      final ciphertext = AesGcm.encrypt(plaintext, key);
      final decrypted = AesGcm.decrypt(ciphertext, key);

      expect(decrypted, equals(plaintext));
    });

    test('encrypt produces different ciphertext each time (random nonce)', () {
      final key = AesGcm.generateKey();
      final plaintext = Uint8List.fromList(utf8.encode('Same message'));

      final ciphertext1 = AesGcm.encrypt(plaintext, key);
      final ciphertext2 = AesGcm.encrypt(plaintext, key);

      // Different nonces should produce different ciphertexts
      expect(ciphertext1, isNot(equals(ciphertext2)));

      // But both should decrypt to the same plaintext
      expect(AesGcm.decrypt(ciphertext1, key), equals(plaintext));
      expect(AesGcm.decrypt(ciphertext2, key), equals(plaintext));
    });

    test('decrypt fails with wrong key', () {
      final key1 = AesGcm.generateKey();
      final key2 = AesGcm.generateKey();
      final plaintext = Uint8List.fromList(utf8.encode('Secret'));

      final ciphertext = AesGcm.encrypt(plaintext, key1);

      expect(
        () => AesGcm.decrypt(ciphertext, key2),
        throwsArgumentError,
      );
    });

    test('decrypt fails with tampered ciphertext', () {
      final key = AesGcm.generateKey();
      final plaintext = Uint8List.fromList(utf8.encode('Secret'));

      final ciphertext = AesGcm.encrypt(plaintext, key);

      // Tamper with the ciphertext (not the nonce)
      ciphertext[AesGcm.nonceLength + 5] ^= 0xFF;

      expect(
        () => AesGcm.decrypt(ciphertext, key),
        throwsArgumentError,
      );
    });

    test('encrypt/decrypt with AAD works', () {
      final key = AesGcm.generateKey();
      final plaintext = Uint8List.fromList(utf8.encode('Secret'));
      final aad = Uint8List.fromList(utf8.encode('additional authenticated data'));

      final ciphertext = AesGcm.encrypt(plaintext, key, aad);
      final decrypted = AesGcm.decrypt(ciphertext, key, aad);

      expect(decrypted, equals(plaintext));
    });

    test('decrypt fails with wrong AAD', () {
      final key = AesGcm.generateKey();
      final plaintext = Uint8List.fromList(utf8.encode('Secret'));
      final aad1 = Uint8List.fromList(utf8.encode('correct aad'));
      final aad2 = Uint8List.fromList(utf8.encode('wrong aad'));

      final ciphertext = AesGcm.encrypt(plaintext, key, aad1);

      expect(
        () => AesGcm.decrypt(ciphertext, key, aad2),
        throwsArgumentError,
      );
    });

    test('generateKey produces 32-byte key', () {
      final key = AesGcm.generateKey();
      expect(key.length, equals(AesGcm.keyLength));
    });

    test('generateSalt produces correct length', () {
      final salt16 = AesGcm.generateSalt();
      expect(salt16.length, equals(16));

      final salt32 = AesGcm.generateSalt(length: 32);
      expect(salt32.length, equals(32));
    });

    test('deriveKey produces consistent output', () {
      final password = 'testpassword123';
      final salt = AesGcm.generateSalt();

      final key1 = AesGcm.deriveKey(password, salt, iterations: 1000);
      final key2 = AesGcm.deriveKey(password, salt, iterations: 1000);

      expect(key1, equals(key2));
      expect(key1.length, equals(AesGcm.keyLength));
    });

    test('deriveKey produces different output for different passwords', () {
      final salt = AesGcm.generateSalt();

      final key1 = AesGcm.deriveKey('password1', salt, iterations: 1000);
      final key2 = AesGcm.deriveKey('password2', salt, iterations: 1000);

      expect(key1, isNot(equals(key2)));
    });

    test('deriveKey produces different output for different salts', () {
      final password = 'samepassword';
      final salt1 = AesGcm.generateSalt();
      final salt2 = AesGcm.generateSalt();

      final key1 = AesGcm.deriveKey(password, salt1, iterations: 1000);
      final key2 = AesGcm.deriveKey(password, salt2, iterations: 1000);

      expect(key1, isNot(equals(key2)));
    });

    test('encrypt rejects invalid key length', () {
      final shortKey = Uint8List(16); // Should be 32
      final plaintext = Uint8List.fromList(utf8.encode('test'));

      expect(
        () => AesGcm.encrypt(plaintext, shortKey),
        throwsArgumentError,
      );
    });

    test('decrypt rejects invalid key length', () {
      final shortKey = Uint8List(16);
      final fakeCiphertext = Uint8List(50);

      expect(
        () => AesGcm.decrypt(fakeCiphertext, shortKey),
        throwsArgumentError,
      );
    });

    test('decrypt rejects too-short ciphertext', () {
      final key = AesGcm.generateKey();
      final shortCiphertext = Uint8List(10); // Less than nonce + tag

      expect(
        () => AesGcm.decrypt(shortCiphertext, key),
        throwsArgumentError,
      );
    });

    test('handles empty plaintext', () {
      final key = AesGcm.generateKey();
      final plaintext = Uint8List(0);

      final ciphertext = AesGcm.encrypt(plaintext, key);
      final decrypted = AesGcm.decrypt(ciphertext, key);

      expect(decrypted, equals(plaintext));
    });

    test('handles large plaintext', () {
      final key = AesGcm.generateKey();
      // 1MB of data
      final plaintext = Uint8List(1024 * 1024);
      for (int i = 0; i < plaintext.length; i++) {
        plaintext[i] = i % 256;
      }

      final ciphertext = AesGcm.encrypt(plaintext, key);
      final decrypted = AesGcm.decrypt(ciphertext, key);

      expect(decrypted, equals(plaintext));
    });
  });
}
