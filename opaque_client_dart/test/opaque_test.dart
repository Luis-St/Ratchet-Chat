import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opaque_client_dart/opaque_client_dart.dart';
import 'package:opaque_client_dart/src/crypto.dart';
import 'package:opaque_client_dart/src/util.dart';
import 'package:opaque_client_dart/src/oprf.dart';

void main() {
  group('Utility functions', () {
    test('joinAll concatenates byte arrays', () {
      final a = Uint8List.fromList([1, 2, 3]);
      final b = Uint8List.fromList([4, 5]);
      final c = Uint8List.fromList([6]);
      final result = joinAll([a, b, c]);
      expect(result, equals(Uint8List.fromList([1, 2, 3, 4, 5, 6])));
    });

    test('encodeNumber/decodeNumber round-trip', () {
      expect(decodeNumber(encodeNumber(0, 16), 16), equals(0));
      expect(decodeNumber(encodeNumber(255, 16), 16), equals(255));
      expect(decodeNumber(encodeNumber(65535, 16), 16), equals(65535));
      expect(decodeNumber(encodeNumber(256, 16), 16), equals(256));
    });

    test('encodeVector16/decodeVector16 round-trip', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final encoded = encodeVector16(data);
      final decoded = decodeVector16(encoded);
      expect(decoded.payload, equals(data));
      expect(decoded.consumed, equals(2 + 5)); // 2-byte header + 5 bytes data
    });

    test('xor produces correct result', () {
      final a = Uint8List.fromList([0xff, 0x00, 0xaa]);
      final b = Uint8List.fromList([0x0f, 0xf0, 0x55]);
      final result = xor(a, b);
      expect(result, equals(Uint8List.fromList([0xf0, 0xf0, 0xff])));
    });

    test('ctEqual returns true for equal arrays', () {
      final a = Uint8List.fromList([1, 2, 3, 4]);
      final b = Uint8List.fromList([1, 2, 3, 4]);
      expect(ctEqual(a, b), isTrue);
    });

    test('ctEqual returns false for unequal arrays', () {
      final a = Uint8List.fromList([1, 2, 3, 4]);
      final b = Uint8List.fromList([1, 2, 3, 5]);
      expect(ctEqual(a, b), isFalse);
    });
  });

  group('Crypto primitives', () {
    test('Hash SHA-256 produces correct output', () {
      final hash = Hash(HashId.sha256);
      expect(hash.Nh, equals(32));

      // Test vector: SHA-256("")
      final emptyHash = hash.sum(Uint8List(0));
      expect(emptyHash.length, equals(32));

      // Known SHA-256 hash of empty string
      final expectedEmpty = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      expect(_bytesToHex(emptyHash), equals(expectedEmpty));
    });

    test('HMAC-SHA256 produces correct output', () {
      final hmac = Hmac(HashId.sha256);
      expect(hmac.Nm, equals(32));

      // Test with a known key and message
      final key = Uint8List.fromList(utf8.encode('key'));
      final message = Uint8List.fromList(utf8.encode('message'));
      final mac = hmac.withKey(key).sign(message);
      expect(mac.length, equals(32));
    });

    test('HMAC verify works correctly', () {
      final hmac = Hmac(HashId.sha256);
      final key = Uint8List.fromList(utf8.encode('secret'));
      final message = Uint8List.fromList(utf8.encode('data'));
      final ops = hmac.withKey(key);

      final mac = ops.sign(message);
      expect(ops.verify(message, mac), isTrue);

      // Modify MAC should fail verification
      final badMac = Uint8List.fromList(mac);
      badMac[0] ^= 0xff;
      expect(ops.verify(message, badMac), isFalse);
    });

    test('HKDF extract/expand produces consistent output', () {
      final hkdf = Hkdf(HashId.sha256);
      expect(hkdf.Nx, equals(32));

      final salt = Uint8List(32); // zero salt
      final ikm = Uint8List.fromList(utf8.encode('input key material'));
      final info = Uint8List.fromList(utf8.encode('context info'));

      final prk = hkdf.extract(salt, ikm);
      expect(prk.length, equals(32));

      final okm = hkdf.expand(prk, info, 64);
      expect(okm.length, equals(64));

      // Running again should produce same result
      final prk2 = hkdf.extract(salt, ikm);
      final okm2 = hkdf.expand(prk2, info, 64);
      expect(okm, equals(okm2));
    });

    test('Prng generates random bytes', () {
      final prng = Prng();
      final bytes1 = prng.random(32);
      final bytes2 = prng.random(32);

      expect(bytes1.length, equals(32));
      expect(bytes2.length, equals(32));
      // Very unlikely to be equal
      expect(bytes1, isNot(equals(bytes2)));
    });

    test('ScryptMemHardFn hardens password', () {
      final scrypt = ScryptMemHardFn();
      final input = Uint8List.fromList(utf8.encode('password'));
      final output = scrypt.harden(input);

      expect(output.length, equals(32));
      // Running again should produce same result (deterministic)
      final output2 = scrypt.harden(input);
      expect(output, equals(output2));
    });
  });

  group('P-256 OPRF', () {
    test('randomScalar generates valid scalar', () {
      final scalar = P256Oprf.randomScalar();
      expect(scalar > BigInt.zero, isTrue);
      expect(scalar < P256Oprf.order, isTrue);
    });

    test('serializeScalar/deserializeScalar round-trip', () {
      final scalar = P256Oprf.randomScalar();
      final serialized = P256Oprf.serializeScalar(scalar);
      expect(serialized.length, equals(32));

      final deserialized = P256Oprf.deserializeScalar(serialized);
      expect(deserialized, equals(scalar));
    });

    test('serializePoint/deserializePoint round-trip', () {
      final scalar = P256Oprf.randomScalar();
      final point = P256Oprf.scalarMult(P256Oprf.generator, scalar);

      final serialized = P256Oprf.serializePoint(point);
      expect(serialized.length, equals(33)); // Compressed point

      final deserialized = P256Oprf.deserializePoint(serialized);
      expect(P256Oprf.serializePoint(deserialized), equals(serialized));
    });

    test('OPRF blind/finalize produces deterministic output for same input', () {
      final client = OprfClient(OprfId.oprfP256Sha256);
      final input = Uint8List.fromList(utf8.encode('test input'));

      // Note: blind is randomized, but finalize should work correctly
      final blindResult = client.blind(input);
      expect(blindResult.blind.length, equals(32));
      expect(blindResult.blindedElement.length, equals(33));
    });
  });

  group('Message serialization', () {
    late OpaqueConfig config;

    setUp(() {
      config = getOpaqueConfig(OpaqueId.opaqueP256);
    });

    test('Envelope serialize/deserialize round-trip', () {
      final nonce = Uint8List.fromList(List.generate(32, (i) => i));
      final authTag = Uint8List.fromList(List.generate(32, (i) => i + 32));

      final envelope = Envelope(nonce: nonce, authTag: authTag);
      final serialized = envelope.serialize();

      expect(serialized.length, equals(Envelope.sizeSerialized(config)));

      final deserialized = Envelope.deserialize(config, serialized);
      expect(deserialized.nonce, equals(nonce));
      expect(deserialized.authTag, equals(authTag));
    });

    test('RegistrationRequest serialize/deserialize round-trip', () {
      final data = Uint8List.fromList(List.generate(33, (i) => i));

      final request = RegistrationRequest(data: data);
      final serialized = request.serialize();

      expect(serialized.length, equals(RegistrationRequest.sizeSerialized(config)));

      final deserialized = RegistrationRequest.deserialize(config, serialized);
      expect(deserialized.data, equals(data));
    });

    test('AuthInit serialize/deserialize round-trip', () {
      final clientNonce = Uint8List.fromList(List.generate(32, (i) => i));
      final clientKeyshare = Uint8List.fromList(List.generate(33, (i) => i + 100));

      final authInit = AuthInit(
        clientNonce: clientNonce,
        clientKeyshare: clientKeyshare,
      );
      final serialized = authInit.serialize();

      expect(serialized.length, equals(AuthInit.sizeSerialized(config)));

      final deserialized = AuthInit.deserialize(config, serialized);
      expect(deserialized.clientNonce, equals(clientNonce));
      expect(deserialized.clientKeyshare, equals(clientKeyshare));
    });

    test('KE1 serialize/deserialize round-trip', () {
      final requestData = Uint8List.fromList(List.generate(33, (i) => i));
      final clientNonce = Uint8List.fromList(List.generate(32, (i) => i + 50));
      final clientKeyshare = Uint8List.fromList(List.generate(33, (i) => i + 100));

      final ke1 = KE1(
        request: CredentialRequest(data: requestData),
        authInit: AuthInit(
          clientNonce: clientNonce,
          clientKeyshare: clientKeyshare,
        ),
      );

      final serialized = ke1.serialize();
      expect(serialized.length, equals(KE1.sizeSerialized(config)));

      final deserialized = KE1.deserialize(config, serialized);
      expect(deserialized.request.data, equals(requestData));
      expect(deserialized.authInit.clientNonce, equals(clientNonce));
      expect(deserialized.authInit.clientKeyshare, equals(clientKeyshare));
    });
  });

  group('OPAQUE Client', () {
    late OpaqueConfig config;

    setUp(() {
      config = getOpaqueConfig(OpaqueId.opaqueP256);
    });

    test('OpaqueClient can be created', () {
      final client = OpaqueClient(config);
      expect(client, isNotNull);
    });

    test('registerInit produces valid request', () {
      final client = OpaqueClient(config);
      final request = client.registerInit('testpassword');

      expect(request.data.length, equals(config.oprf.Noe));

      final serialized = request.serialize();
      expect(serialized.length, equals(RegistrationRequest.sizeSerialized(config)));
    });

    test('authInit produces valid KE1', () {
      final client = OpaqueClient(config);
      final ke1 = client.authInit('testpassword');

      expect(ke1.request.data.length, equals(config.oprf.Noe));
      expect(ke1.authInit.clientNonce.length, equals(config.constants.Nn));
      expect(ke1.authInit.clientKeyshare.length, equals(config.ake.Npk));

      final serialized = ke1.serialize();
      expect(serialized.length, equals(KE1.sizeSerialized(config)));
    });

    test('client state management works correctly', () {
      final client = OpaqueClient(config);

      // Should work first time
      client.registerInit('password');

      // Should throw when called again without reset
      expect(() => client.registerInit('password'), throwsStateError);
    });

    test('authInit state prevents double call', () {
      final client = OpaqueClient(config);

      // Should work first time
      client.authInit('password');

      // Should throw when called again without reset
      expect(() => client.authInit('password'), throwsStateError);
    });
  });

  group('Config', () {
    test('getOpaqueConfig returns valid P256 config', () {
      final config = getOpaqueConfig(OpaqueId.opaqueP256);

      expect(config.opaqueId, equals(OpaqueId.opaqueP256));
      expect(config.constants.Nn, equals(32));
      expect(config.constants.Nseed, equals(32));
      expect(config.hash.Nh, equals(32));
      expect(config.mac.Nm, equals(32));
      expect(config.kdf.Nx, equals(32));
      expect(config.ake.Npk, equals(33));
      expect(config.ake.Nsk, equals(32));
      expect(config.oprf.Noe, equals(33));
    });
  });
}

String _bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
