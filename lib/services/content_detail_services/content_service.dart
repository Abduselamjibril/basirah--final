// lib/services/content_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/content_type.dart';
import 'api_service.dart';

class ContentService {
  final ApiService _api;
  final String _apiBaseUrl = "https://admin.basirahtv.com";

  ContentService(this._api);

  Future<List<dynamic>> fetchEpisodes(
      ContentType type, int parentId, String token) async {
    final prefs = await SharedPreferences.getInstance();
    // Cache key now includes the user's token hash to prevent different users from seeing the same cache
    final cacheKey =
        '${type.apiName}_${parentId}_episodes_cache_${token.hashCode}';

    try {
      final endpoint = '${type.apiEndpoint}/$parentId/episodes';
      // The token is now passed to the api service
      final data = await _api.get(endpoint, token: token);

      List<dynamic> episodesList;
      if (data is Map && data.containsKey('data') && data['data'] is List) {
        episodesList = data['data'];
      } else if (data is List) {
        episodesList = data;
      } else {
        throw Exception('Invalid API response format for episodes.');
      }

      await prefs.setString(cacheKey, json.encode(episodesList));
      return episodesList;
    } catch (e) {
      print('API failed for ${type.apiName} episodes, trying cache: $e');
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null) {
        try {
          return json.decode(cachedJson) as List<dynamic>;
        } catch (cacheError) {
          throw Exception('Failed to load from API and cache was invalid.');
        }
      }
      rethrow;
    }
  }

  Future<void> trackContentStart(
      ContentType type, int contentId, String token) async {
    try {
      // The phone_number field is removed from the body.
      final body = {
        // 'phone_number': phoneNumber, // REMOVED
        'content_id': contentId,
        'content_type': type.apiName,
      };
      // The token is now passed to the api service
      await _api.post('progress/start', body, token: token);
    } catch (e) {
      print('Non-critical error sending start tracking request: $e');
    }
  }

  // No changes needed for these helper methods
  String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$_apiBaseUrl/storage/$path';
  }

  String? getPlayableUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) {
      return path;
    }
    return '$_apiBaseUrl/storage/$path';
  }
}
