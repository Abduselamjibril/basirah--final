// lib/services/bookmark_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

// A single, unified bookmark service that handles all bookmark operations.
class BookmarkService {
  final String _baseUrl = 'https://admin.basirahtv.com/api';
  final _logger = Logger(
    printer: PrettyPrinter(methodCount: 1, printEmojis: true),
  );

  // Helper to build standard headers with the auth token.
  Map<String, String> _buildHeaders(String token) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Fetches ALL bookmarks for the user in a single API call.
  /// The response is a list of bookmark objects, each containing the actual content.
  /// [
  ///   { "id": 1, "bookmarkable_type": "App\\Models\\Course", "bookmarkable": { "id": 5, "name": "Course Name", ... } },
  ///   { "id": 2, "bookmarkable_type": "App\\Models\\Episode", "bookmarkable": { "id": 12, "title": "Episode Title", ... } }
  /// ]
  Future<List<dynamic>> fetchAllBookmarks(String token) async {
    _logger.i('Fetching all bookmarks for the current user via new API.');
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/bookmarks'), // The new GET endpoint
        headers: _buildHeaders(token),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        // Handle Laravel API Resource wrapping (it puts data in a 'data' key)
        final List<dynamic> data = (decoded is Map && decoded.containsKey('data'))
            ? decoded['data'] as List<dynamic>
            : decoded as List<dynamic>;
        
        _logger.d('Successfully fetched ${data.length} total bookmarks.');
        return data;
      } else {
        _logger.e(
            'Failed to fetch bookmarks. Status: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Failed to load bookmarks.');
      }
    } catch (e, s) {
      _logger.e('Error in fetchAllBookmarks', e, s);
      rethrow; // Rethrow to allow the UI to handle the error
    }
  }

  /// Toggles a bookmark for any content type (parent or episode) using a single endpoint.
  Future<String> toggleBookmark({
    required String token,
    required String bookmarkableType, // e.g., 'course', 'commentary_episode'
    required int bookmarkableId,
  }) async {
    _logger.i(
        'Toggling bookmark for type: $bookmarkableType, id: $bookmarkableId');
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/bookmarks/toggle'), // The new POST endpoint
        headers: _buildHeaders(token),
        body: json.encode({
          'type': bookmarkableType,
          'id': bookmarkableId,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final message = responseBody['message'] as String;
        _logger.d('Bookmark toggled successfully: $message');
        return message;
      } else {
        _logger.e(
            'Failed to toggle bookmark. Status: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Failed to update bookmark.');
      }
    } catch (e, s) {
      _logger.e('Error in toggleBookmark', e, s);
      rethrow;
    }
  }
}
