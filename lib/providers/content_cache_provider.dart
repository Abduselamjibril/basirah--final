import 'package:flutter/foundation.dart';
import '../services/content_services/data_fetcher.dart'; // Make sure this import is correct

class ContentCacheProvider with ChangeNotifier {
  // A map to hold all our cached content, keyed by content type.
  final Map<String, List<dynamic>> _cache = {};

  // A map to track the loading state for each content type.
  final Map<String, bool> _loadingState = {};

  // A flag to ensure we only fetch once on app start, unless forced.
  bool _isInitialFetchComplete = false;

  // --- Public Getters to access the data ---
  List<dynamic> get courses => _cache['courses'] ?? [];
  List<dynamic> get surahs => _cache['surahs'] ?? [];
  List<dynamic> get stories => _cache['stories'] ?? [];
  List<dynamic> get deeperLooks => _cache['deeperLooks'] ?? [];
  List<dynamic> get commentaries => _cache['commentaries'] ?? [];

  // --- Public Getters for loading states ---
  bool isLoading(String contentType) => _loadingState[contentType] ?? false;
  bool get isAnythingLoading =>
      _loadingState.values.any((isLoading) => isLoading);

  // --- The main data fetching and caching method ---
  Future<void> fetchAllContent(
      {required String token, bool forceRefresh = false}) async {
    // If we're already fetching, don't start another request.
    if (isAnythingLoading && !forceRefresh) return;

    // If data is already loaded and we're not forcing a refresh, do nothing.
    if (_isInitialFetchComplete && !forceRefresh) return;

    // Set loading states to true for all content types
    _setLoadingState(true);

    try {
      final results = await Future.wait([
        fetchAndCacheContent(
            apiEndpoint: 'courses',
            cacheKey: 'courses_cache',
            token: token,
            forceRefresh: forceRefresh),
        fetchAndCacheContent(
            apiEndpoint: 'surahs',
            cacheKey: 'surahs_cache_v2',
            token: token,
            forceRefresh: forceRefresh),
        fetchAndCacheContent(
            apiEndpoint: 'stories',
            cacheKey: 'stories_cache',
            token: token,
            forceRefresh: forceRefresh),
        fetchAndCacheContent(
            apiEndpoint: 'deeper-looks',
            cacheKey: 'deeper_looks_cache_v2',
            token: token,
            forceRefresh: forceRefresh),
        fetchAndCacheContent(
            apiEndpoint: 'commentaries',
            cacheKey: 'commentaries_cache_v2',
            token: token,
            forceRefresh: forceRefresh),
      ]);

      // Update the cache with the new data
      _cache['courses'] = results[0]['data'];
      _cache['surahs'] = results[1]['data'];
      _cache['stories'] = results[2]['data'];
      _cache['deeperLooks'] = results[3]['data'];
      _cache['commentaries'] = results[4]['data'];

      _isInitialFetchComplete = true;
    } catch (e) {
      print("Error fetching all content for cache: $e");
      // Optionally, you can clear the cache on error or handle it differently
      // _cache.clear();
    } finally {
      // Always set loading states to false after the operation.
      _setLoadingState(false);
    }
  }

  void _setLoadingState(bool isLoading) {
    _loadingState['courses'] = isLoading;
    _loadingState['surahs'] = isLoading;
    _loadingState['stories'] = isLoading;
    _loadingState['deeperLooks'] = isLoading;
    _loadingState['commentaries'] = isLoading;
    // Notify all listening widgets that the state has changed.
    notifyListeners();
  }
}
