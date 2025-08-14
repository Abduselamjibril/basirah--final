// lib/services/auth_http_service.dart

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../topbar/login_page.dart'; // Adjust path to your LoginPage
import '../main.dart'; // Adjust path to your main.dart (for navigatorKey)

class AuthException implements Exception {
  final String message;
  final int? statusCode;
  AuthException(this.message, {this.statusCode});

  @override
  String toString() => "AuthException: $message (Status Code: $statusCode)";
}

class AuthHttpService {
  final String _baseUrl = "https://admin.basirahtv.com/api";
  final http.Client _client;

  AuthHttpService({http.Client? client}) : _client = client ?? http.Client();

  // =========================================================================
  // --- ADD THIS METHOD ---
  // This is the public method the splash screen will call to check auth status.
  // =========================================================================
  Future<bool> isLoggedIn() async {
    // We can simply reuse your existing _getToken method.
    // If a token exists and is not an empty string, the user is logged in.
    final String? token = await _getToken();
    return token != null && token.isNotEmpty;
  }
  // =========================================================================
  // --- End of new method ---
  // =========================================================================

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    // Your code correctly looks for the key 'token'.
    return prefs.getString('token');
  }

  Future<Map<String, String>> _getHeaders(
      {bool requireAuth = true, String? customContentType}) async {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': customContentType ?? 'application/json',
    };

    if (requireAuth) {
      final token = await _getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      } else {
        print("AuthHttpService: Auth required but no token found locally.");
        // Potentially throw an AuthException here if strict about it before API call
        // For now, let the API call return 401, which will then be handled.
      }
    }
    return headers;
  }

  Future<void> _handleUnauthorized() async {
    print("AuthHttpService: Handling 401 Unauthorized.");
    final prefs = await SharedPreferences.getInstance();
    final currentRouteName = navigatorKey.currentState != null
        ? ModalRoute.of(navigatorKey.currentContext!)?.settings.name
        : null;

    // Only clear and navigate if not already on login to prevent loops
    if (currentRouteName != '/login') {
      await prefs.remove('token');
      await prefs.setBool('isLoggedIn', false);
      await prefs.remove('userName');
      await prefs.remove('userPhoneNumber');
      await prefs.remove('is_premium');
      await prefs.remove('current_session_device_id');

      if (navigatorKey.currentState != null &&
          navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          const SnackBar(
            content: Text(
                'Your session has expired or was logged out. Please log in again.'),
            backgroundColor: Colors.orangeAccent,
            duration: Duration(seconds: 4),
          ),
        );
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => LoginPage(),
              settings: const RouteSettings(name: '/login')),
          (route) => false,
        );
      } else {
        print(
            "AuthHttpService: navigatorKey or context is null. Cannot navigate for 401.");
      }
    } else {
      print(
          "AuthHttpService: Already on login page or cannot determine current page. Skipping navigation for 401.");
    }
  }

  Future<http.Response> _processResponse(http.Response response,
      {bool requireAuth = true}) async {
    if (response.statusCode == 401 && requireAuth) {
      await _handleUnauthorized();
      throw AuthException("Unauthorized: Session terminated or token invalid.",
          statusCode: 401);
    }
    // You could add more common error handling here, e.g., for 500 server errors
    return response;
  }

  Future<http.Response> get(String endpoint,
      {bool requireAuth = true, Map<String, String>? queryParams}) async {
    final uri =
        Uri.parse('$_baseUrl/$endpoint').replace(queryParameters: queryParams);
    final headers = await _getHeaders(requireAuth: requireAuth);
    print("AuthHttpService GET: $uri");
    final response = await _client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 20));
    print("AuthHttpService GET Response ${response.statusCode} from: $uri");
    return _processResponse(response, requireAuth: requireAuth);
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body,
      {bool requireAuth = true, String? customContentType}) async {
    final uri = Uri.parse('$_baseUrl/$endpoint');
    final headers = await _getHeaders(
        requireAuth: requireAuth, customContentType: customContentType);
    final encodedBody = jsonEncode(body);
    print("AuthHttpService POST: $uri Body: $encodedBody");
    final response = await _client
        .post(uri, headers: headers, body: encodedBody)
        .timeout(const Duration(seconds: 25));
    print("AuthHttpService POST Response ${response.statusCode} from: $uri");
    return _processResponse(response, requireAuth: requireAuth);
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> body,
      {bool requireAuth = true, String? customContentType}) async {
    final uri = Uri.parse('$_baseUrl/$endpoint');
    final headers = await _getHeaders(
        requireAuth: requireAuth, customContentType: customContentType);
    final encodedBody = jsonEncode(body);
    print("AuthHttpService PUT: $uri Body: $encodedBody");
    final response = await _client
        .put(uri, headers: headers, body: encodedBody)
        .timeout(const Duration(seconds: 25));
    print("AuthHttpService PUT Response ${response.statusCode} from: $uri");
    return _processResponse(response, requireAuth: requireAuth);
  }

  Future<http.Response> delete(String endpoint,
      {Map<String, dynamic>? body, bool requireAuth = true}) async {
    final uri = Uri.parse('$_baseUrl/$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);
    final encodedBody = body != null ? jsonEncode(body) : null;
    print(
        "AuthHttpService DELETE: $uri ${encodedBody != null ? 'Body: $encodedBody' : ''}");
    final response = await _client
        .delete(uri, headers: headers, body: encodedBody)
        .timeout(const Duration(seconds: 20));
    print("AuthHttpService DELETE Response ${response.statusCode} from: $uri");
    return _processResponse(response, requireAuth: requireAuth);
  }

  void dispose() {
    _client.close();
  }
}
