/// Tests for the message encryption/decryption flow.
/// This simulates the complete end-to-end message flow between two users.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ratchet_chat/src/crypto/aes_gcm.dart';
import 'package:ratchet_chat/src/crypto/ml_dsa.dart';
import 'package:ratchet_chat/src/crypto/ml_kem.dart';

void main() {
  group('Message Encryption Flow', () {
    // Simulated users
    late IdentityKeyPair aliceIdentity;
    late TransportKeyPair aliceTransport;
    late Uint8List aliceLocalKey;

    late IdentityKeyPair bobIdentity;
    late TransportKeyPair bobTransport;
    late Uint8List bobLocalKey;

    setUp(() {
      // Generate keys for Alice
      aliceIdentity = MlDsa65.generateKeyPair();
      aliceTransport = MlKem768.generateKeyPair();
      aliceLocalKey = AesGcm.generateKey();

      // Generate keys for Bob
      bobIdentity = MlDsa65.generateKeyPair();
      bobTransport = MlKem768.generateKeyPair();
      bobLocalKey = AesGcm.generateKey();
    });

    test('Alice can send encrypted message to Bob', () {
      final messageContent = 'Hello Bob! This is a secret message.';
      final messageId = 'msg-123';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // === ALICE (Sender) ===

      // 1. Create message payload
      final payload = {
        'id': messageId,
        'from': 'alice@server.com',
        'to': 'bob@server.com',
        'content': messageContent,
        'timestamp': timestamp,
      };

      // 2. Sign with Alice's identity key
      final payloadBytes = utf8.encode(jsonEncode(payload));
      final signature = MlDsa65.sign(
        Uint8List.fromList(payloadBytes),
        aliceIdentity.secretKey,
      );

      // 3. Add signature to payload
      final signedPayload = {
        ...payload,
        'signature': base64Encode(signature),
      };

      // 4. Encapsulate with Bob's transport public key
      final encap = MlKem768.encapsulate(bobTransport.publicKey);

      // 5. Encrypt with shared secret
      final encryptedPayload = AesGcm.encrypt(
        Uint8List.fromList(utf8.encode(jsonEncode(signedPayload))),
        encap.sharedSecret,
      );

      // 6. Alice also stores locally with her local key
      final aliceLocalEncrypted = AesGcm.encrypt(
        Uint8List.fromList(utf8.encode(messageContent)),
        aliceLocalKey,
      );

      // === Transmission (encap.ciphertext + encryptedPayload) ===

      // === BOB (Receiver) ===

      // 1. Decapsulate to get shared secret
      final bobSharedSecret = MlKem768.decapsulate(
        encap.ciphertext,
        bobTransport.secretKey,
      );

      // Verify shared secrets match
      expect(bobSharedSecret, equals(encap.sharedSecret));

      // 2. Decrypt payload
      final decryptedPayloadBytes = AesGcm.decrypt(encryptedPayload, bobSharedSecret);
      final decryptedPayload = jsonDecode(utf8.decode(decryptedPayloadBytes)) as Map<String, dynamic>;

      // 3. Verify signature
      final receivedSignature = base64Decode(decryptedPayload['signature'] as String);
      final messageData = Map<String, dynamic>.from(decryptedPayload);
      messageData.remove('signature');

      final isValid = MlDsa65.verify(
        Uint8List.fromList(utf8.encode(jsonEncode(messageData))),
        receivedSignature,
        aliceIdentity.publicKey, // Bob uses Alice's public key
      );

      expect(isValid, isTrue);

      // 4. Extract content
      final receivedContent = decryptedPayload['content'] as String;
      expect(receivedContent, equals(messageContent));

      // 5. Bob re-encrypts with his local key
      final bobLocalEncrypted = AesGcm.encrypt(
        Uint8List.fromList(utf8.encode(receivedContent)),
        bobLocalKey,
      );

      // === Verify local storage works ===

      // Alice can decrypt her local copy
      final aliceDecrypted = AesGcm.decrypt(aliceLocalEncrypted, aliceLocalKey);
      expect(utf8.decode(aliceDecrypted), equals(messageContent));

      // Bob can decrypt his local copy
      final bobDecrypted = AesGcm.decrypt(bobLocalEncrypted, bobLocalKey);
      expect(utf8.decode(bobDecrypted), equals(messageContent));
    });

    test('Message signature verification fails with wrong sender key', () {
      final messageContent = 'Secret message';

      // Alice signs a message
      final payload = {
        'id': 'msg-1',
        'from': 'alice@server.com',
        'to': 'bob@server.com',
        'content': messageContent,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final payloadBytes = utf8.encode(jsonEncode(payload));
      final signature = MlDsa65.sign(
        Uint8List.fromList(payloadBytes),
        aliceIdentity.secretKey,
      );

      // Generate a fake "Charlie" who claims to be Alice
      final charlieIdentity = MlDsa65.generateKeyPair();

      // Bob tries to verify with Charlie's key (thinking it's Alice's)
      final isValid = MlDsa65.verify(
        Uint8List.fromList(payloadBytes),
        signature,
        charlieIdentity.publicKey, // Wrong key!
      );

      expect(isValid, isFalse);
    });

    test('Message decryption fails with wrong transport key', () {
      final messageContent = 'Secret message';

      // Encrypt for Bob
      final encap = MlKem768.encapsulate(bobTransport.publicKey);
      final encrypted = AesGcm.encrypt(
        Uint8List.fromList(utf8.encode(messageContent)),
        encap.sharedSecret,
      );

      // Alice (wrong recipient) tries to decrypt
      final aliceSharedSecret = MlKem768.decapsulate(
        encap.ciphertext,
        aliceTransport.secretKey, // Wrong key!
      );

      // Shared secrets should be different
      expect(aliceSharedSecret, isNot(equals(encap.sharedSecret)));

      // Decryption should fail
      expect(
        () => AesGcm.decrypt(encrypted, aliceSharedSecret),
        throwsArgumentError,
      );
    });

    test('Message tampered during transit fails verification', () {
      final messageContent = 'Original message';

      // Alice encrypts for Bob
      final encap = MlKem768.encapsulate(bobTransport.publicKey);
      final encrypted = AesGcm.encrypt(
        Uint8List.fromList(utf8.encode(messageContent)),
        encap.sharedSecret,
      );

      // Attacker tampers with ciphertext
      final tampered = Uint8List.fromList(encrypted);
      tampered[20] ^= 0xFF;

      // Bob tries to decrypt tampered message
      final bobSharedSecret = MlKem768.decapsulate(
        encap.ciphertext,
        bobTransport.secretKey,
      );

      expect(
        () => AesGcm.decrypt(tampered, bobSharedSecret),
        throwsArgumentError,
      );
    });

    test('Forward secrecy: new encapsulation produces new shared secret', () {
      // First message
      final encap1 = MlKem768.encapsulate(bobTransport.publicKey);

      // Second message
      final encap2 = MlKem768.encapsulate(bobTransport.publicKey);

      // Different encapsulations should produce different shared secrets
      expect(encap1.sharedSecret, isNot(equals(encap2.sharedSecret)));
      expect(encap1.ciphertext, isNot(equals(encap2.ciphertext)));

      // But Bob can decrypt both
      final secret1 = MlKem768.decapsulate(encap1.ciphertext, bobTransport.secretKey);
      final secret2 = MlKem768.decapsulate(encap2.ciphertext, bobTransport.secretKey);

      expect(secret1, equals(encap1.sharedSecret));
      expect(secret2, equals(encap2.sharedSecret));
    });

    test('Multiple messages in conversation work correctly', () {
      final messages = [
        'Hello!',
        'How are you?',
        'I am doing great, thanks for asking!',
        'That is wonderful to hear.',
      ];

      for (var i = 0; i < messages.length; i++) {
        final isAlice = i % 2 == 0;
        final sender = isAlice ? 'alice' : 'bob';
        final recipient = isAlice ? 'bob' : 'alice';
        final senderIdentity = isAlice ? aliceIdentity : bobIdentity;
        final recipientTransport = isAlice ? bobTransport : aliceTransport;
        final senderLocalKey = isAlice ? aliceLocalKey : bobLocalKey;
        final recipientLocalKey = isAlice ? bobLocalKey : aliceLocalKey;
        final recipientTransportSecretKey = isAlice
            ? bobTransport.secretKey
            : aliceTransport.secretKey;

        final content = messages[i];

        // Sender creates and encrypts message
        final payload = {
          'id': 'msg-$i',
          'from': sender,
          'to': recipient,
          'content': content,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        final payloadBytes = utf8.encode(jsonEncode(payload));
        final signature = MlDsa65.sign(
          Uint8List.fromList(payloadBytes),
          senderIdentity.secretKey,
        );

        final signedPayload = {...payload, 'signature': base64Encode(signature)};
        final encap = MlKem768.encapsulate(recipientTransport.publicKey);
        final encrypted = AesGcm.encrypt(
          Uint8List.fromList(utf8.encode(jsonEncode(signedPayload))),
          encap.sharedSecret,
        );

        // Sender stores locally
        final senderLocal = AesGcm.encrypt(
          Uint8List.fromList(utf8.encode(content)),
          senderLocalKey,
        );

        // Recipient decrypts
        final sharedSecret = MlKem768.decapsulate(
          encap.ciphertext,
          recipientTransportSecretKey,
        );
        final decrypted = AesGcm.decrypt(encrypted, sharedSecret);
        final decryptedPayload = jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>;

        // Verify and extract
        final receivedContent = decryptedPayload['content'] as String;
        expect(receivedContent, equals(content));

        // Recipient stores locally
        final recipientLocal = AesGcm.encrypt(
          Uint8List.fromList(utf8.encode(receivedContent)),
          recipientLocalKey,
        );

        // Both can read their local copies
        expect(
          utf8.decode(AesGcm.decrypt(senderLocal, senderLocalKey)),
          equals(content),
        );
        expect(
          utf8.decode(AesGcm.decrypt(recipientLocal, recipientLocalKey)),
          equals(content),
        );
      }
    });

    test('Large message encryption works', () {
      // 100KB message
      final largeContent = 'X' * 100000;

      final encap = MlKem768.encapsulate(bobTransport.publicKey);
      final encrypted = AesGcm.encrypt(
        Uint8List.fromList(utf8.encode(largeContent)),
        encap.sharedSecret,
      );

      final sharedSecret = MlKem768.decapsulate(
        encap.ciphertext,
        bobTransport.secretKey,
      );

      final decrypted = AesGcm.decrypt(encrypted, sharedSecret);
      expect(utf8.decode(decrypted), equals(largeContent));
    });

    test('Unicode message content is preserved', () {
      final unicodeContent = '你好世界! 🎉 Привет мир! مرحبا بالعالم';

      final encap = MlKem768.encapsulate(bobTransport.publicKey);
      final encrypted = AesGcm.encrypt(
        Uint8List.fromList(utf8.encode(unicodeContent)),
        encap.sharedSecret,
      );

      final sharedSecret = MlKem768.decapsulate(
        encap.ciphertext,
        bobTransport.secretKey,
      );

      final decrypted = AesGcm.decrypt(encrypted, sharedSecret);
      expect(utf8.decode(decrypted), equals(unicodeContent));
    });
  });
}
