// lib/services/api_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class ApiService {
  final String _baseUrl = "https://admin.basirahtv.com/api";
  final Duration _timeout = const Duration(seconds: 20);

  /// Centralized method to build headers.
  /// If a token is provided, it adds the 'Authorization' header.
  Map<String, String> _buildHeaders(String? token) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Performs a GET request. Requires a token for authenticated routes.
  Future<dynamic> get(String endpoint, {String? token}) async {
    final uri = Uri.parse('$_baseUrl/$endpoint');
    final response =
        await http.get(uri, headers: _buildHeaders(token)).timeout(_timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      // It's good practice to handle 401 specifically, though AuthHttpService also does this.
      if (response.statusCode == 401) {
        throw Exception('Unauthorized: Access is denied. Please log in again.');
      }
      throw Exception(
          'API Error on GET $endpoint: ${response.statusCode} - ${response.body}');
    }
  }

  /// Performs a POST request. Requires a token for authenticated routes.
  Future<dynamic> post(String endpoint, Map<String, dynamic> body,
      {String? token}) async {
    final uri = Uri.parse('$_baseUrl/$endpoint');
    final response = await http
        .post(
          uri,
          headers: _buildHeaders(token),
          body: json.encode(body),
        )
        .timeout(_timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      if (response.statusCode == 401) {
        throw Exception('Unauthorized: Access is denied. Please log in again.');
      }
      throw Exception(
          'API Error on POST $endpoint: ${response.statusCode} - ${response.body}');
    }
  }

  /// Performs a DELETE request. Requires a token for authenticated routes.
  Future<dynamic> delete(String endpoint,
      {Map<String, dynamic>? body, String? token}) async {
    final uri = Uri.parse('$_baseUrl/$endpoint');
    final response = await http
        .delete(
          uri,
          headers: _buildHeaders(token),
          body: body != null ? json.encode(body) : null,
        )
        .timeout(_timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return json.decode(response.body);
      } catch (e) {
        return {'message': 'Success'};
      }
    } else {
      if (response.statusCode == 401) {
        throw Exception('Unauthorized: Access is denied. Please log in again.');
      }
      throw Exception(
          'API Error on DELETE $endpoint: ${response.statusCode} - ${response.body}');
    }
  }
}
