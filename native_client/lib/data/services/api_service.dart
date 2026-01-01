import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/auth_exceptions.dart';

/// Service for making HTTP requests to the Ratchet Chat API.
class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _baseUrl;
  String? _token;

  /// Sets the base URL for API requests.
  void setBaseUrl(String url) {
    _baseUrl = url;
  }

  /// Sets the authentication token.
  void setToken(String? token) {
    _token = token;
  }

  /// Gets the current base URL.
  String? get baseUrl => _baseUrl;

  /// Gets the current token.
  String? get token => _token;

  /// Builds headers for requests.
  Map<String, String> _buildHeaders({bool includeAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (includeAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  /// Makes a GET request.
  Future<Map<String, dynamic>> get(
    String path, {
    bool includeAuth = true,
  }) async {
    _ensureBaseUrl();
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl$path'),
        headers: _buildHeaders(includeAuth: includeAuth),
      );
      return _handleResponse(response);
    } on SocketException {
      throw const NetworkException('Unable to connect to server');
    } on http.ClientException {
      throw const NetworkException('Network request failed');
    }
  }

  /// Makes a POST request.
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool includeAuth = true,
  }) async {
    _ensureBaseUrl();
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl$path'),
        headers: _buildHeaders(includeAuth: includeAuth),
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } on SocketException {
      throw const NetworkException('Unable to connect to server');
    } on http.ClientException {
      throw const NetworkException('Network request failed');
    }
  }

  /// Makes a DELETE request.
  Future<void> delete(String path, {bool includeAuth = true}) async {
    _ensureBaseUrl();
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl$path'),
        headers: _buildHeaders(includeAuth: includeAuth),
      );
      if (response.statusCode == 401) {
        throw const SessionExpiredException();
      }
      if (response.statusCode >= 400) {
        throw ServerException.fromStatusCode(response.statusCode);
      }
    } on SocketException {
      throw const NetworkException('Unable to connect to server');
    } on http.ClientException {
      throw const NetworkException('Network request failed');
    }
  }

  /// Validates that a URL points to a valid Ratchet Chat server.
  Future<bool> validateServer(String url) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$url/.well-known/ratchet-chat/federation.json'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void _ensureBaseUrl() {
    if (_baseUrl == null || _baseUrl!.isEmpty) {
      throw const InvalidServerException('Server URL not configured');
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      throw const SessionExpiredException();
    }

    if (response.statusCode == 404) {
      throw const UserNotFoundException();
    }

    if (response.statusCode == 409) {
      throw const UsernameTakenException();
    }

    if (response.statusCode == 429) {
      final retryAfter =
          int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
      throw RateLimitedException(retryAfterSeconds: retryAfter);
    }

    if (response.statusCode >= 500) {
      throw ServerException.fromStatusCode(response.statusCode);
    }

    if (response.statusCode >= 400) {
      final body = _tryParseJson(response.body);
      final message = body?['error'] ?? body?['message'] ?? 'Request failed';
      if (message.toString().toLowerCase().contains('credentials') ||
          message.toString().toLowerCase().contains('password') ||
          message.toString().toLowerCase().contains('invalid')) {
        throw const InvalidCredentialsException();
      }
      throw ServerException(message.toString());
    }

    return _tryParseJson(response.body) ?? {};
  }

  Map<String, dynamic>? _tryParseJson(String body) {
    try {
      if (body.isEmpty) return {};
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Disposes the HTTP client.
  void dispose() {
    _client.close();
  }
}
