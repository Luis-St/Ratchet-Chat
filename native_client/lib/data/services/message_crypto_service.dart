import 'dart:convert';
import 'dart:typed_data';

import 'package:native_client/data/models/message.dart';
import 'package:native_client/data/models/transit_payload.dart';
import 'package:native_client/data/services/crypto_service.dart';
import 'package:native_client/data/services/pq_crypto_service.dart';
import 'package:native_client/data/models/user_session.dart';

/// Prefix for message signatures (must match web client)
const String messageSignaturePrefix = 'ratchet-chat:message:v1';

/// Transit envelope structure (JSON format for encrypted messages)
class TransitEnvelope {
  /// Encapsulated key from ML-KEM-768 (base64)
  final String cipherText;

  /// Initialization vector for AES-GCM (base64)
  final String iv;

  /// Encrypted payload (base64)
  final String ciphertext;

  TransitEnvelope({
    required this.cipherText,
    required this.iv,
    required this.ciphertext,
  });

  factory TransitEnvelope.fromJson(Map<String, dynamic> json) {
    return TransitEnvelope(
      cipherText: json['cipherText'] as String,
      iv: json['iv'] as String,
      ciphertext: json['ciphertext'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'cipherText': cipherText,
        'iv': iv,
        'ciphertext': ciphertext,
      };

  String toJsonString() => jsonEncode(toJson());

  static TransitEnvelope fromJsonString(String jsonStr) {
    return TransitEnvelope.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
  }
}

/// Service for message-level cryptographic operations.
///
/// Handles:
/// - Transit encryption/decryption (ML-KEM-768 + AES-GCM)
/// - Message signing/verification (ML-DSA-65)
/// - Local storage encryption (AES-GCM with master key)
class MessageCryptoService {
  final PqCryptoService _pqCrypto;
  final CryptoService _crypto;

  MessageCryptoService({
    required PqCryptoService pqCrypto,
    required CryptoService crypto,
  })  : _pqCrypto = pqCrypto,
        _crypto = crypto;

  /// Builds the signature payload matching the web client format.
  ///
  /// Format: JSON.stringify(["ratchet-chat:message:v1", senderHandle, content, messageId])
  Uint8List buildSignaturePayload(
    String senderHandle,
    String content,
    String? messageId,
  ) {
    final payload = messageId != null
        ? [messageSignaturePrefix, senderHandle, content, messageId]
        : [messageSignaturePrefix, senderHandle, content];
    return Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  }

  /// Signs a message with the sender's identity key (ML-DSA-65).
  ///
  /// Returns the signature as a base64 string.
  String signMessage({
    required String senderHandle,
    required String content,
    required String messageId,
    required Uint8List identityPrivateKey,
  }) {
    final payload = buildSignaturePayload(senderHandle, content, messageId);
    final signature = _pqCrypto.sign(payload, identityPrivateKey);
    return base64Encode(signature);
  }

  /// Verifies a message signature with the sender's identity key (ML-DSA-65).
  bool verifySignature({
    required String senderHandle,
    required String content,
    required String messageId,
    required String signature,
    required String publicIdentityKey,
  }) {
    try {
      final payload = buildSignaturePayload(senderHandle, content, messageId);
      final signatureBytes = base64Decode(signature);
      final publicKeyBytes = base64Decode(publicIdentityKey);
      return _pqCrypto.verify(payload, signatureBytes, publicKeyBytes);
    } catch (e) {
      return false;
    }
  }

  /// Encrypts a transit payload for the recipient using ML-KEM-768 + AES-GCM.
  ///
  /// Returns the transit envelope as a JSON string.
  String encryptTransitEnvelope({
    required String payload,
    required String recipientPublicKey,
  }) {
    // Encapsulate shared secret using ML-KEM-768
    final publicKeyBytes = base64Decode(recipientPublicKey);
    final encapResult = _pqCrypto.encapsulate(publicKeyBytes);

    // Encrypt the payload with the shared secret using AES-GCM
    final payloadBytes = Uint8List.fromList(utf8.encode(payload));
    final encrypted = _crypto.encrypt(payloadBytes, encapResult.sharedSecret);

    // Create the transit envelope
    final envelope = TransitEnvelope(
      cipherText: base64Encode(encapResult.ciphertext),
      iv: encrypted.iv,
      ciphertext: encrypted.ciphertext,
    );

    return envelope.toJsonString();
  }

  /// Decrypts a transit envelope using the recipient's private transport key.
  ///
  /// Returns the decrypted payload as bytes.
  Uint8List decryptTransitBlob({
    required String encryptedBlob,
    required Uint8List transportPrivateKey,
  }) {
    // Parse the transit envelope
    final envelope = TransitEnvelope.fromJsonString(encryptedBlob);

    // Decapsulate the shared secret using ML-KEM-768
    final cipherText = base64Decode(envelope.cipherText);
    final sharedSecret = _pqCrypto.decapsulate(cipherText, transportPrivateKey);

    // Decrypt the payload using AES-GCM
    final encryptedPayload = EncryptedPayload(
      ciphertext: envelope.ciphertext,
      iv: envelope.iv,
    );
    return _crypto.decrypt(encryptedPayload, sharedSecret);
  }

  /// Decrypts a transit envelope and parses the payload.
  TransitPayload decryptAndParseTransitPayload({
    required String encryptedBlob,
    required Uint8List transportPrivateKey,
  }) {
    final decrypted = decryptTransitBlob(
      encryptedBlob: encryptedBlob,
      transportPrivateKey: transportPrivateKey,
    );
    final json = jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>;
    return TransitPayload.fromJson(json);
  }

  /// Encrypts a message content for local storage using the master key.
  EncryptedMessagePayload encryptForLocalStorage({
    required MessageContent content,
    required Uint8List masterKey,
  }) {
    final contentBytes = Uint8List.fromList(utf8.encode(jsonEncode(content.toJson())));
    final encrypted = _crypto.encrypt(contentBytes, masterKey);
    return EncryptedMessagePayload(
      encryptedBlob: encrypted.ciphertext,
      iv: encrypted.iv,
    );
  }

  /// Decrypts a message content from local storage using the master key.
  MessageContent decryptFromLocalStorage({
    required EncryptedMessagePayload encrypted,
    required Uint8List masterKey,
  }) {
    final encryptedPayload = EncryptedPayload(
      ciphertext: encrypted.encryptedBlob,
      iv: encrypted.iv,
    );
    final decrypted = _crypto.decrypt(encryptedPayload, masterKey);
    final json = jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>;
    return MessageContent.fromJson(json);
  }

  /// Creates a transit payload for sending a message.
  TransitPayload createTransitPayload({
    required String content,
    required String senderHandle,
    required String messageId,
    required Uint8List identityPrivateKey,
    required String publicIdentityKey,
    String type = 'message',
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderHandle,
  }) {
    final signature = signMessage(
      senderHandle: senderHandle,
      content: content,
      messageId: messageId,
      identityPrivateKey: identityPrivateKey,
    );

    return TransitPayload(
      content: content,
      senderHandle: senderHandle,
      senderSignature: signature,
      senderIdentityKey: publicIdentityKey,
      messageId: messageId,
      type: type,
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
      replyToSenderHandle: replyToSenderHandle,
    );
  }

  /// Creates the full encrypted blob for sending a message.
  String createEncryptedTransitBlob({
    required String content,
    required String senderHandle,
    required String messageId,
    required Uint8List identityPrivateKey,
    required String publicIdentityKey,
    required String recipientPublicTransportKey,
    String type = 'message',
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderHandle,
  }) {
    final transitPayload = createTransitPayload(
      content: content,
      senderHandle: senderHandle,
      messageId: messageId,
      identityPrivateKey: identityPrivateKey,
      publicIdentityKey: publicIdentityKey,
      type: type,
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
      replyToSenderHandle: replyToSenderHandle,
    );

    return encryptTransitEnvelope(
      payload: transitPayload.toJsonString(),
      recipientPublicKey: recipientPublicTransportKey,
    );
  }
}
