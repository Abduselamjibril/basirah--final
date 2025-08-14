// lib/services/bookmark_service.dart

import 'package:logger/logger.dart';
import '../../models/content_type.dart';
import 'api_service.dart';

class BookmarkService {
  final ApiService _api;
  BookmarkService(this._api);

  final _logger = Logger(
    printer: PrettyPrinter(methodCount: 1, colors: true, printEmojis: true),
  );

  /// Fetches all bookmarked episode IDs for the authenticated user.
  Future<Set<int>> fetchAllBookmarkedEpisodeIds(String token) async {
    _logger.i('Fetching all bookmarked episode IDs for the current user.');
    try {
      // The phone_number query parameter is no longer needed.
      final data = await _api.get('bookmarks/all-episodes', token: token);
      final Set<int> allIds = {};

      if (data is Map) {
        data.forEach((key, value) {
          if (value is List) {
            for (var item in value) {
              if (item is Map && item.containsKey('id')) {
                final id = int.tryParse(item['id']?.toString() ?? '');
                if (id != null) {
                  allIds.add(id);
                }
              }
            }
          }
        });
      }
      _logger
          .d('Successfully fetched ${allIds.length} bookmarked episode IDs.');
      return allIds;
    } catch (e, s) {
      _logger.e('Failed to fetch bookmarked episode IDs', e, s);
      _logger.w('Returning an empty set due to the error.');
      return {};
    }
  }

  /// Toggles the bookmark status for a single episode for the authenticated user.
  Future<String> toggleBookmark({
    required String token, // CHANGED: Now requires token
    // required String phoneNumber, // REMOVED
    required ContentType type,
    required int parentId,
    required int episodeId,
  }) async {
    // The phone_number field is removed from the body.
    final body = {
      // 'phone_number': phoneNumber, // REMOVED
      'type': type.apiName,
      'parent_id': parentId,
      'episode_id': episodeId,
    };

    _logger.i(
        'Attempting to toggle bookmark for episode $episodeId (type: ${type.apiName}, parent: $parentId)');

    try {
      final response =
          await _api.post('bookmarks/toggle-episode', body, token: token);
      final message =
          response['message'] ?? 'Bookmark status updated successfully.';
      _logger.d(
          'Bookmark toggle successful for episode $episodeId. API Message: "$message"');
      return message;
    } catch (e, s) {
      _logger.e('Failed to toggle bookmark for episode $episodeId', e, s);
      rethrow;
    }
  }
}
