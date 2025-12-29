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

  final String baseUrl = "https://postumbonal-monatomic-cecelia.ngrok-free.dev/api";
  String? _accessToken;
  String? _refreshToken;

  static const String _keyAccess = 'access_token';
  static const String _keyRefresh = 'refresh_token';

  // --- Token Management ---

  Future<void> setTokens({required String access, required String refresh}) async {
    // Always set in memory first
    _accessToken = access;
    _refreshToken = refresh;

    // Try to persist, but don't crash if plugin fails
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAccess, access);
      await prefs.setString(_keyRefresh, refresh);
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

  /// Reliability Feature: Automatic Retry Mechanism
  /// Retries the request up to [maxRetries] times if a network error occurs.
  Future<dynamic> _requestWithRetry(Future<http.Response> Function() requestFn, {int maxRetries = 3}) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        final response = await requestFn();
        return _processResponse(response);
      } catch (e) {
        attempts++;
        // If it's a known API exception (like 400 Bad Request), don't retry, throw immediately
        if (e is ApiException && (e.statusCode != null && e.statusCode! < 500)) {
          rethrow;
        }

        // Only retry on Network errors (SocketException) or Server errors (500+)
        final isNetworkError = e is SocketException || e is TimeoutException;
        final isServerError = e is ApiException && (e.statusCode == null || e.statusCode! >= 500);

        if (attempts >= maxRetries || (!isNetworkError && !isServerError)) {
          if (e is ApiException) rethrow;
          throw ApiException("Network error after $attempts attempts: ${e.toString()}");
        }

        // Exponential backoff: 1s, 2s, 4s
        if (kDebugMode) print("Request failed, retrying ($attempts/$maxRetries)...");
        await Future.delayed(Duration(seconds: (1 << (attempts - 1))));
      }
    }
  }

  dynamic _processResponse(http.Response response) {
    if (kDebugMode) {
      print("API ${response.request?.method} ${response.request?.url} [${response.statusCode}]");
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
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