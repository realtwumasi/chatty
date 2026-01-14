import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // New API
  final String baseUrl = "https://postumbonal-monatomic-cecelia.ngrok-free.dev/dms/api";

  String? _accessToken;
  String? _refreshToken;
  
  String? get accessToken => _accessToken;
  String? get currentRefreshToken => _refreshToken;

  static const String _keyAccess = 'access_token';
  static const String _keyRefresh = 'refresh_token';

  // Broadcast stream to notify when token changes (e.g. after refresh)
  final _tokenController = StreamController<String>.broadcast();
  Stream<String> get onTokenRefreshed => _tokenController.stream;

  // --- Token Management ---

  Future<void> setTokens({required String access, required String refresh}) async {
    _accessToken = access;
    _refreshToken = refresh;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAccess, access);
      await prefs.setString(_keyRefresh, refresh);

      // Notify listeners (ChatRepository) that we have a new valid token
      _tokenController.add(access);
    } catch (e) {
      if (kDebugMode) print("Storage Warning: Could not save tokens: $e");
    }
  }

  Future<bool> loadTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString(_keyAccess);
      _refreshToken = prefs.getString(_keyRefresh);
    } catch (e) {
      if (kDebugMode) print("Storage Warning: Could not load tokens: $e");
    }
    return _accessToken != null;
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAccess);
      await prefs.remove(_keyRefresh);
    } catch (e) {
      if (kDebugMode) print("Storage Warning: Could not clear tokens: $e");
    }
  }

  // Circuit Breaker State
  DateTime? _throttleUntil;

  // --- Auth & Refresh Logic ---

  Future<bool> refreshToken() async {
    if (_refreshToken == null) return false;
    
    // Respect Circuit Breaker
    if (_throttleUntil != null && DateTime.now().isBefore(_throttleUntil!)) {
      if (kDebugMode) print("API: Circuit Breaker Active. Skipping refresh.");
      return false;
    }

    try {
      if (kDebugMode) print("API: Refreshing token...");
      // Construct refresh URL based on base URL structure
      final refreshUrl = Uri.parse('$baseUrl/auth/token/refresh/');

      final response = await http.post(
        refreshUrl,
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'refresh': _refreshToken}),
      );

      if (response.statusCode == 429) {
         _handleTrottle(response);
         return false;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccess = data['access'];
        // Some APIs rotate refresh tokens, some don't. Use new if available, else keep old.
        final newRefresh = data['refresh'] ?? _refreshToken;

        await setTokens(access: newAccess, refresh: newRefresh);
        if (kDebugMode) print("API: Token refreshed successfully.");
        return true;
      } else {
        if (kDebugMode) print("API: Token refresh failed [${response.statusCode}]");
        await clearTokens();
        return false;
      }
    } catch (e) {
      if (kDebugMode) print("API: Token refresh error: $e");
      return false;
    }
  }

  // --- HTTP Methods ---

  Future<dynamic> get(String endpoint, {Map<String, String>? params}) async {
    if (_accessToken == null) await loadTokens();
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: params);
    return _requestWithRetry(() => http.get(uri, headers: _headers));
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    if (_accessToken == null) await loadTokens();
    final uri = Uri.parse('$baseUrl$endpoint');
    return _requestWithRetry(() => http.post(uri, headers: _headers, body: jsonEncode(body)));
  }

  // Added DELETE method
  Future<dynamic> delete(String endpoint) async {
    if (_accessToken == null) await loadTokens();
    final uri = Uri.parse('$baseUrl$endpoint');
    return _requestWithRetry(() => http.delete(uri, headers: _headers));
  }

  // Added MARK READ method (Bulk)
  Future<void> markMessagesAsRead(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    if (_accessToken == null) await loadTokens();

    final uri = Uri.parse('$baseUrl/messages/mark_read/');
    await _requestWithRetry(() => http.post(
        uri,
        headers: _headers,
        body: jsonEncode({'message_ids': messageIds})
    ));
  }

  // Get Read Receipts
  Future<List<dynamic>> getReadReceipts(String messageId) async {
    if (_accessToken == null) await loadTokens();
    final uri = Uri.parse('$baseUrl/messages/read-receipts/').replace(queryParameters: {'message_id': messageId});
    final response = await _requestWithRetry(() => http.get(uri, headers: _headers));
    if (response is Map && response['readers'] != null) {
      return response['readers'];
    }
    return [];
  }

  // --- E2E Encryption APIs ---
  
  /// Upload user's public key for E2E encryption
  Future<void> uploadPublicKey(String publicKey) async {
    if (_accessToken == null) await loadTokens();
    final uri = Uri.parse('$baseUrl/user-keys/me/public-key/');
    await _requestWithRetry(() => http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'public_key': publicKey}),
    ));
    if (kDebugMode) print('E2E: Public key uploaded successfully');
  }

  /// Get a user's public key for encryption
  /// Returns null if user hasn't enabled encryption (not an error)
  Future<String?> getUserPublicKey(String userId) async {
    if (_accessToken == null) await loadTokens();
    try {
      final uri = Uri.parse('$baseUrl/user-keys/$userId/public-key/');
      final response = await _requestWithRetry(() => http.get(uri, headers: _headers));
      if (response is Map && response['public_key'] != null) {
        return response['public_key'];
      }
      // User hasn't enabled encryption - this is expected, not an error
      if (response is Map && response['error'] != null) {
        if (kDebugMode) print('E2E: User $userId has not enabled encryption (will send unencrypted)');
      }
    } catch (e) {
      // Only log actual errors, not "user hasn't enabled encryption"
      final errorStr = e.toString();
      if (!errorStr.contains('not enabled')) {
        if (kDebugMode) print('E2E: Error fetching public key for $userId: $e');
      }
    }
    return null;
  }

  /// Get public keys for multiple users (for group encryption)
  Future<Map<String, String>> getBulkPublicKeys(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    if (_accessToken == null) await loadTokens();
    
    try {
      final uri = Uri.parse('$baseUrl/bulk-public-keys/');
      final response = await _requestWithRetry(() => http.post(
        uri,
        headers: _headers,
        body: jsonEncode({'user_ids': userIds}),
      ));
      
      if (response is Map && response['public_keys'] != null) {
        final publicKeys = response['public_keys'] as Map<String, dynamic>;
        return publicKeys.map((key, value) => MapEntry(key, value.toString()));
      }
    } catch (e) {
      if (kDebugMode) print('E2E: Failed to get bulk public keys: $e');
    }
    return {};
  }

  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  /// Reliability Feature: Automatic Retry & Token Refresh
  Future<dynamic> _requestWithRetry(Future<http.Response> Function() requestFn, {int maxRetries = 3}) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      // Respect Circuit Breaker
      if (_throttleUntil != null) {
        if (DateTime.now().isBefore(_throttleUntil!)) {
          final waitSeconds = _throttleUntil!.difference(DateTime.now()).inSeconds;
          if (kDebugMode) print("API: Circuit Breaker Active. Waiting ${waitSeconds}s...");
          throw ApiException("Requests throttled. Please wait ${waitSeconds}s.", statusCode: 429);
        } else {
          _throttleUntil = null; // Reset if expired
        }
      }

      try {
        final response = await requestFn();

        // Handle 401 Unauthorized (Token Expiry)
        if (response.statusCode == 401) {
          if (kDebugMode) print("API 401: Unauthorized. Attempting refresh...");
          final refreshed = await refreshToken();
          if (refreshed) {
            // Retry the request *once* with the new token
            final retryResponse = await requestFn();
            return _processResponse(retryResponse);
          } else {
            // Refresh failed, propagate error to trigger logout
            throw ApiException("Session expired. Please log in again.", statusCode: 401);
          }
        }

        return _processResponse(response);
      } catch (e) {
        // If it's a 401 from the check above, rethrow immediately
        if (e is ApiException && e.statusCode == 401) rethrow;

        attempts++;

        // Don't retry client errors (4xx) except 401/408/429
        if (e is ApiException && (e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500)) {
          rethrow;
        }

        final isNetworkError = e is SocketException || e is TimeoutException;
        final isServerError = e is ApiException && (e.statusCode == null || e.statusCode! >= 500);

        if (attempts >= maxRetries || (!isNetworkError && !isServerError)) {
          if (e is ApiException) rethrow;
          throw ApiException("Network error: ${e.toString()}");
        }

        if (kDebugMode) print("Request failed, retrying ($attempts/$maxRetries)...");
        await Future.delayed(Duration(seconds: (1 << (attempts - 1))));
      }
    }
  }

  void _handleTrottle(http.Response response) {
    int waitSeconds = 60; // Default
    final retryAfter = response.headers['retry-after'];
    if (retryAfter != null) {
      waitSeconds = int.tryParse(retryAfter) ?? 60;
    } else {
       // Try to parse from body
       try {
         final body = jsonDecode(response.body);
         // Example: "Expected available in 1691 seconds."
         if (body is Map && body['detail'] != null) {
           final detail = body['detail'].toString();
           final check = RegExp(r'in (\d+) seconds').firstMatch(detail);
           if (check != null) {
             waitSeconds = int.parse(check.group(1)!);
           }
         }
       } catch (_) {}
    }

    _throttleUntil = DateTime.now().add(Duration(seconds: waitSeconds + 1)); // +1 buffer
    if (kDebugMode) print("API: 429 Throttled. Pausing all requests for ${waitSeconds}s.");
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode == 429) {
      _handleTrottle(response);
      throw ApiException("Too many requests. Please wait.", statusCode: 429);
    }

    if (kDebugMode) {
      print("API ${response.request?.method} ${response.request?.url} [${response.statusCode}]");
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      try {
         return jsonDecode(response.body);
      } catch (e) {
         // Some endpoints might return non-JSON 200 OK
         return {};
      }
    } else {
      String msg = "Unknown Error";
      try {
        final body = jsonDecode(response.body);
        if (body is Map) {
          msg = body['detail'] ?? body['message'] ?? body.toString();
        } else {
          msg = body.toString();
        }
      } catch (_) {
        msg = "Error ${response.statusCode}";
      }
      throw ApiException(msg, statusCode: response.statusCode);
    }
  }
}