// Messages API endpoints.

import 'api_client.dart';

/// Incoming message from the queue.
class IncomingMessage {
  final String id;
  final String senderHandle;
  final String encapsulatedKey;
  final String ciphertext;
  final DateTime timestamp;

  IncomingMessage({
    required this.id,
    required this.senderHandle,
    required this.encapsulatedKey,
    required this.ciphertext,
    required this.timestamp,
  });

  factory IncomingMessage.fromJson(Map<String, dynamic> json) {
    return IncomingMessage(
      id: json['id'] as String,
      senderHandle: json['senderHandle'] as String,
      encapsulatedKey: json['encapsulatedKey'] as String,
      ciphertext: json['ciphertext'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Stored message from the vault.
class StoredMessage {
  final String id;
  final String conversationId;
  final String senderHandle;
  final String recipientHandle;
  final String encryptedContent;
  final DateTime timestamp;

  StoredMessage({
    required this.id,
    required this.conversationId,
    required this.senderHandle,
    required this.recipientHandle,
    required this.encryptedContent,
    required this.timestamp,
  });

  factory StoredMessage.fromJson(Map<String, dynamic> json) {
    return StoredMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderHandle: json['senderHandle'] as String,
      recipientHandle: json['recipientHandle'] as String,
      encryptedContent: json['encryptedContent'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Send message request.
class SendMessageRequest {
  final String recipientHandle;
  final String encapsulatedKey;
  final String ciphertext;

  SendMessageRequest({
    required this.recipientHandle,
    required this.encapsulatedKey,
    required this.ciphertext,
  });

  Map<String, dynamic> toJson() {
    return {
      'recipientHandle': recipientHandle,
      'encapsulatedKey': encapsulatedKey,
      'ciphertext': ciphertext,
    };
  }
}

/// Send message response.
class SendMessageResponse {
  final String messageId;

  SendMessageResponse({required this.messageId});

  factory SendMessageResponse.fromJson(Map<String, dynamic> json) {
    return SendMessageResponse(
      messageId: json['messageId'] as String,
    );
  }
}

/// Messages API.
class MessagesApi {
  final ApiClient _client;

  MessagesApi(this._client);

  /// Send an encrypted message.
  Future<SendMessageResponse> sendMessage(SendMessageRequest request) async {
    final response = await _client.post<SendMessageResponse>(
      '/messages/send',
      (json) => SendMessageResponse.fromJson(json as Map<String, dynamic>),
      body: request.toJson(),
      includeAuth: true,
    );
    return response.data;
  }

  /// Get incoming messages from the queue.
  Future<List<IncomingMessage>> getQueue() async {
    final response = await _client.get<List<IncomingMessage>>(
      '/messages/queue',
      (json) {
        final list = json as List<dynamic>;
        return list
            .map((item) => IncomingMessage.fromJson(item as Map<String, dynamic>))
            .toList();
      },
      includeAuth: true,
    );
    return response.data;
  }

  /// Store a message from the queue to the vault.
  Future<void> storeMessage({
    required String messageId,
    required String encryptedContent,
  }) async {
    await _client.post<void>(
      '/messages/queue/$messageId/store',
      (_) {},
      body: {
        'encryptedContent': encryptedContent,
      },
      includeAuth: true,
    );
  }

  /// Get stored messages from the vault.
  Future<List<StoredMessage>> getVault({
    String? conversationId,
    int? limit,
    int? offset,
  }) async {
    final queryParams = <String, dynamic>{};
    if (conversationId != null) {
      queryParams['conversationId'] = conversationId;
    }
    if (limit != null) {
      queryParams['limit'] = limit;
    }
    if (offset != null) {
      queryParams['offset'] = offset;
    }

    final response = await _client.get<List<StoredMessage>>(
      '/messages/vault',
      (json) {
        final list = json as List<dynamic>;
        return list
            .map((item) => StoredMessage.fromJson(item as Map<String, dynamic>))
            .toList();
      },
      queryParams: queryParams.isNotEmpty ? queryParams : null,
      includeAuth: true,
    );
    return response.data;
  }

  /// Relay a message to a federated server.
  Future<SendMessageResponse> relayMessage({
    required String targetServer,
    required String recipientHandle,
    required String encapsulatedKey,
    required String ciphertext,
    required String senderSignature,
  }) async {
    final response = await _client.post<SendMessageResponse>(
      '/messages/federation/relay',
      (json) => SendMessageResponse.fromJson(json as Map<String, dynamic>),
      body: {
        'targetServer': targetServer,
        'recipientHandle': recipientHandle,
        'encapsulatedKey': encapsulatedKey,
        'ciphertext': ciphertext,
        'senderSignature': senderSignature,
      },
      includeAuth: true,
    );
    return response.data;
  }

  /// Delete a message from the queue (after processing).
  Future<void> deleteFromQueue(String messageId) async {
    await _client.delete<void>(
      '/messages/queue/$messageId',
      (_) {},
      includeAuth: true,
    );
  }
}
