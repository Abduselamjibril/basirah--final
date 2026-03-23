// lib/providers/bookmark_provider.dart
import 'package:flutter/material.dart';
import '../services/bookmark_service.dart';

class BookmarkProvider extends ChangeNotifier {
  final BookmarkService _service = BookmarkService();
  
  // Key format: "type_id"
  final Set<String> _bookmarkedKeys = {};
  List<dynamic> _allBookmarks = [];
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error; 
  Set<String> get bookmarkedKeys => _bookmarkedKeys;
  List<dynamic> get allBookmarks => _allBookmarks;

  bool isBookmarked(String type, int id) {
    return _bookmarkedKeys.contains("${type}_$id");
  }

  void clear() {
    _bookmarkedKeys.clear();
    _allBookmarks.clear();
    _error = null;
    notifyListeners();
  }

  Future<void> fetchBookmarks(String token, {bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final bookmarks = await _service.fetchAllBookmarks(token);
      _allBookmarks = List<dynamic>.from(bookmarks);
      _bookmarkedKeys.clear();
      for (var b in _allBookmarks) {
        final type = _mapModelToApiType(b['bookmarkable_type']);
        final id = b['bookmarkable_id'];
        if (type.isNotEmpty) {
          _bookmarkedKeys.add("${type}_$id");
        }
      }
      
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    } catch (e) {
      if (!silent) {
        _isLoading = false;
        _error = e.toString();
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> toggleBookmark({
    required String token,
    required String type,
    required int id,
  }) async {
    final key = "${type}_$id";
    final wasBookmarked = _bookmarkedKeys.contains(key);

    // Optimistic UI update
    if (wasBookmarked) {
      _bookmarkedKeys.remove(key);
    } else {
      _bookmarkedKeys.add(key);
    }
    notifyListeners();

    try {
      await _service.toggleBookmark(
        token: token,
        bookmarkableType: type,
        bookmarkableId: id,
      );
      // Success - silently update the master list in the background
      fetchBookmarks(token, silent: true);
    } catch (e) {
      // Rollback on error
      if (wasBookmarked) {
        _bookmarkedKeys.add(key);
      } else {
        _bookmarkedKeys.remove(key);
      }
      notifyListeners();
      rethrow;
    }
  }

  String _mapModelToApiType(String modelPath) {
    if (modelPath.endsWith('SurahEpisode')) return 'surah_episode';
    if (modelPath.endsWith('StoryEpisode')) return 'story_episode';
    if (modelPath.endsWith('CommentaryEpisode')) return 'commentary_episode';
    if (modelPath.endsWith('DeeperLookEpisode')) return 'deeper_look_episode';
    if (modelPath.endsWith('Course')) return 'course';
    if (modelPath.endsWith('Surah')) return 'surah';
    if (modelPath.endsWith('Story')) return 'story';
    if (modelPath.endsWith('Commentary')) return 'commentary';
    if (modelPath.endsWith('DeeperLook')) return 'deeper_look';
    if (modelPath.endsWith('Episode')) return 'episode';
    return '';
  }
}
