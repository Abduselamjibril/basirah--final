// lib/services/parent_bookmark_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Builds the authentication headers.
Map<String, String> _buildHeaders(String? token) {
  final headers = {'Accept': 'application/json'};
  if (token != null) {
    headers['Authorization'] = 'Bearer $token';
  }
  return headers;
}

/// Fetches all bookmarked parent content IDs for the authenticated user.
Future<Set<int>> fetchBookmarkedIds({
  required String token, // <-- MODIFIED: Now requires token
  // required String phoneNumber, // REMOVED
  required String contentType,
}) async {
  try {
    // phone_number is removed from the query parameters
    final response = await http.get(
      Uri.parse('https://admin.basirahtv.com/api/bookmarks/all-parents'),
      headers: _buildHeaders(token), // Pass the token in the header
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final String key =
          (contentType == 'story') ? 'stories' : '${contentType}s';

      if (data.containsKey(key) && data[key] is List) {
        return (data[key] as List)
            .map((item) => int.tryParse(item['id'].toString()))
            .whereType<int>()
            .toSet();
      }
    }
  } catch (e) {
    // Error handling can be added here if needed, for now it returns an empty set.
  }
  return {};
}

/// Toggles a bookmark for a specific parent item. Returns true on success.
Future<bool> toggleBookmark({
  required String token, // <-- MODIFIED: Now requires token
  // required String phoneNumber, // REMOVED
  required int contentId,
  required String contentType,
}) async {
  try {
    final headers = _buildHeaders(token);
    headers['Content-Type'] =
        'application/json'; // Ensure content type for POST

    final response = await http.post(
      Uri.parse('https://admin.basirahtv.com/api/bookmarks/toggle-parent'),
      headers: headers,
      // The phone_number field is removed from the body
      body: json.encode({
        // 'phone_number': phoneNumber, // REMOVED
        'type': contentType,
        'id': contentId
      }),
    );
    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  } catch (e) {
    return false;
  }
}
