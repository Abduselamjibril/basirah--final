// lib/services/content_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Fetches, caches, and returns content from the API.
/// Now requires a token for all requests, as all content is protected.
Future<Map<String, dynamic>> fetchAndCacheContent({
  required String apiEndpoint,
  required String cacheKey,
  required String token, // <-- ADDED: Token is now mandatory
  bool forceRefresh = false,
  bool isDataNested = true,
}) async {
  List<dynamic>? data;
  String? error;

  final prefs = await SharedPreferences.getInstance();
  // User-specific cache key to prevent data leaks between accounts on the same device
  final userSpecificCacheKey = '${cacheKey}_${token.hashCode}';

  if (forceRefresh) {
    await prefs.remove(userSpecificCacheKey);
  }

  // 1. Try loading from cache
  try {
    final cachedDataString = prefs.getString(userSpecificCacheKey);
    if (cachedDataString != null) {
      final decodedCache = json.decode(cachedDataString);
      data = isDataNested &&
              decodedCache is Map &&
              decodedCache.containsKey('data')
          ? decodedCache['data']
          : decodedCache;
    }
  } catch (e) {
    // Error reading from cache, will proceed to fetch from network.
  }

  // 2. Fetch from network
  try {
    final response = await http.get(
      Uri.parse('https://admin.basirahtv.com/api/$apiEndpoint'),
      // ADDED: Headers with authentication token
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final decodedResponse = json.decode(response.body);
      data = isDataNested &&
              decodedResponse is Map &&
              decodedResponse.containsKey('data')
          ? decodedResponse['data']
          : decodedResponse;
      error = null;
      await prefs.setString(userSpecificCacheKey, response.body);
    } else {
      throw Exception('API Error (Status: ${response.statusCode})');
    }
  } on TimeoutException {
    if (data == null) error = "Request timed out. Please try again.";
  } on http.ClientException {
    if (data == null) error = "Network Error. Please check connection.";
  } on Exception catch (e) {
    // Check for 401 specifically
    if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
      error = "Your session has expired. Please log in again.";
    } else if (data == null) {
      error = "An unexpected error occurred.";
    }
  }

  return {'data': data ?? [], 'error': error};
}
