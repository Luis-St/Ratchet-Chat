// Base API client with authentication interceptors.

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// API error response.
class ApiError implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? details;

  ApiError({
    required this.statusCode,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'ApiError($statusCode): $message';

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode >= 500;
}

/// API response wrapper.
class ApiResponse<T> {
  final T data;
  final int statusCode;
  final Map<String, String> headers;

  ApiResponse({
    required this.data,
    required this.statusCode,
    required this.headers,
  });
}

/// Token provider for authentication.
typedef TokenProvider = Future<String?> Function();

/// Token refresh callback.
typedef TokenRefreshCallback = Future<String?> Function();

/// Base API client.
class ApiClient {
  final String baseUrl;
  final http.Client _httpClient;
  TokenProvider? _tokenProvider;
  TokenRefreshCallback? _onTokenRefresh;

  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Set the token provider for authentication.
  void setTokenProvider(TokenProvider provider) {
    _tokenProvider = provider;
  }

  /// Set the callback for token refresh.
  void setTokenRefreshCallback(TokenRefreshCallback callback) {
    _onTokenRefresh = callback;
  }

  /// Build headers for requests.
  Future<Map<String, String>> _buildHeaders({
    bool includeAuth = true,
    Map<String, String>? additionalHeaders,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth && _tokenProvider != null) {
      final token = await _tokenProvider!();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    return headers;
  }

  /// Build full URL from path.
  Uri _buildUrl(String path, [Map<String, dynamic>? queryParams]) {
    final uri = Uri.parse('$baseUrl$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams.map(
        (key, value) => MapEntry(key, value.toString()),
      ));
    }
    return uri;
  }

  /// Parse response body.
  dynamic _parseResponse(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }

    final contentType = response.headers['content-type'] ?? '';
    if (contentType.contains('application/json')) {
      return jsonDecode(response.body);
    }

    return response.body;
  }

  /// Handle response and throw errors if needed.
  Future<ApiResponse<T>> _handleResponse<T>(
    http.Response response,
    T Function(dynamic json) fromJson,
  ) async {
    final body = _parseResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponse<T>(
        data: fromJson(body),
        statusCode: response.statusCode,
        headers: response.headers,
      );
    }

    // Handle 401 - try to refresh token
    if (response.statusCode == 401 && _onTokenRefresh != null) {
      final newToken = await _onTokenRefresh!();
      if (newToken != null) {
        // Token refreshed - caller should retry
        throw ApiError(
          statusCode: 401,
          message: 'Token refreshed, please retry',
          details: {'tokenRefreshed': true},
        );
      }
    }

    // Extract error message
    String message = 'Unknown error';
    Map<String, dynamic>? details;

    if (body is Map<String, dynamic>) {
      message = body['error'] as String? ??
          body['message'] as String? ??
          'Unknown error';
      details = body;
    } else if (body is String) {
      message = body;
    }

    throw ApiError(
      statusCode: response.statusCode,
      message: message,
      details: details,
    );
  }

  /// GET request.
  Future<ApiResponse<T>> get<T>(
    String path,
    T Function(dynamic json) fromJson, {
    Map<String, dynamic>? queryParams,
    bool includeAuth = true,
    Map<String, String>? additionalHeaders,
  }) async {
    final headers = await _buildHeaders(
      includeAuth: includeAuth,
      additionalHeaders: additionalHeaders,
    );
    final uri = _buildUrl(path, queryParams);

    final response = await _httpClient.get(uri, headers: headers);
    return _handleResponse(response, fromJson);
  }

  /// POST request with JSON body.
  Future<ApiResponse<T>> post<T>(
    String path,
    T Function(dynamic json) fromJson, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
    Map<String, String>? additionalHeaders,
  }) async {
    final headers = await _buildHeaders(
      includeAuth: includeAuth,
      additionalHeaders: additionalHeaders,
    );
    final uri = _buildUrl(path);

    final response = await _httpClient.post(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response, fromJson);
  }

  /// POST request with raw bytes.
  Future<ApiResponse<T>> postBytes<T>(
    String path,
    T Function(dynamic json) fromJson, {
    required Uint8List body,
    String contentType = 'application/octet-stream',
    bool includeAuth = true,
    Map<String, String>? additionalHeaders,
  }) async {
    final headers = await _buildHeaders(
      includeAuth: includeAuth,
      additionalHeaders: additionalHeaders,
    );
    headers['Content-Type'] = contentType;
    final uri = _buildUrl(path);

    final response = await _httpClient.post(uri, headers: headers, body: body);
    return _handleResponse(response, fromJson);
  }

  /// PUT request with JSON body.
  Future<ApiResponse<T>> put<T>(
    String path,
    T Function(dynamic json) fromJson, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
    Map<String, String>? additionalHeaders,
  }) async {
    final headers = await _buildHeaders(
      includeAuth: includeAuth,
      additionalHeaders: additionalHeaders,
    );
    final uri = _buildUrl(path);

    final response = await _httpClient.put(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response, fromJson);
  }

  /// DELETE request.
  Future<ApiResponse<T>> delete<T>(
    String path,
    T Function(dynamic json) fromJson, {
    bool includeAuth = true,
    Map<String, String>? additionalHeaders,
  }) async {
    final headers = await _buildHeaders(
      includeAuth: includeAuth,
      additionalHeaders: additionalHeaders,
    );
    final uri = _buildUrl(path);

    final response = await _httpClient.delete(uri, headers: headers);
    return _handleResponse(response, fromJson);
  }

  /// Close the HTTP client.
  void close() {
    _httpClient.close();
  }
}
