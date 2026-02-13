import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart'; // --- LOGGER --- Import logger
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'Story_Detail_Page.dart'; // Corrected filename to match convention
import '../../theme_provider.dart';
// --- NEW IMPORTS ---
import '../services/bookmark_service.dart'; // Using the new unified service
import '../services/content_services/data_fetcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/content_cache_provider.dart';

class StoryNightPage extends StatefulWidget {
  const StoryNightPage({super.key});
  @override
  _StoryNightPageState createState() => _StoryNightPageState();
}

class _StoryNightPageState extends State<StoryNightPage> {
  // --- STATE AND SERVICE REFACTOR ---
  final BookmarkService _bookmarkService = BookmarkService();
  List<dynamic> stories = [];
  List<dynamic> filteredStories = [];
  Map<int, bool> bookmarks = {};
  bool isLoading = true;
  String? errorMessage;
  TextEditingController searchController = TextEditingController();
  bool _imagesPrefetched = false;
  final DefaultCacheManager _cacheManager = DefaultCacheManager();

  final _logger = Logger(); // --- LOGGER --- Initialize the logger

  @override
  void initState() {
    super.initState();
    _logger.i("StoryNightPage initialized."); // --- LOGGER ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
    searchController.addListener(_filterStories);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _filterStories() {
    final query = searchController.text.toLowerCase();
    _logger.d("Filtering stories with query: '$query'"); // --- LOGGER ---
    setState(() {
      filteredStories = stories.where((story) {
        final title = story['name']?.toString().toLowerCase() ?? '';
        return title.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchData({bool forceRefresh = false}) async {
    if (!mounted) return;
    _logger
        .i("Fetching stories... forceRefresh: $forceRefresh"); // --- LOGGER ---
    final cacheProvider =
        Provider.of<ContentCacheProvider>(context, listen: false);

    if (!forceRefresh && cacheProvider.hasData('stories')) {
      final cached = cacheProvider.getData('stories');
      setState(() {
        stories = cached;
        filteredStories = cached;
        isLoading = false;
        errorMessage = null;
      });
      _prefetchImages(cached);
      _filterStories();
      return;
    }

    setState(() {
      isLoading = true;
      if (forceRefresh) errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
      _logger.w(
          "Cannot fetch stories: User is not logged in (token is null)."); // --- LOGGER ---
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = "Please log in to view stories.";
          stories = [];
          bookmarks = {};
        });
      }
      return;
    }

    try {
      // --- FETCH LOGIC REFACTORED ---
      _logger
          .d("Fetching stories and bookmarks in parallel."); // --- LOGGER ---
      final contentFuture = fetchAndCacheContent(
        apiEndpoint: 'stories',
        cacheKey: 'stories_cache',
        token: token,
        forceRefresh: forceRefresh,
      );
      final bookmarksFuture = _bookmarkService.fetchAllBookmarks(token);

      final result = await contentFuture;
      final allBookmarks = await bookmarksFuture;

      final bookmarkedIds = allBookmarks
          .where((b) => b['bookmarkable_type'].endsWith('Story'))
          // --- FIX --- Changed unsafe cast to robust parsing
          .map((b) => int.parse(b['bookmarkable_id'].toString()))
          .toSet();

      if (!mounted) return;
      setState(() {
        stories = result['data'];
        errorMessage = result['error'];
        bookmarks = {
          for (var item in stories)
            int.parse(item['id'].toString()):
                bookmarkedIds.contains(int.parse(item['id'].toString()))
        };
        isLoading = false;
        _filterStories();
      });

      cacheProvider.setData('stories', stories);
      _prefetchImages(stories);
      // --- LOGGER ---
      _logger.i(
          "Successfully fetched ${stories.length} stories and ${bookmarks.length} story bookmarks.");

      if (errorMessage != null && stories.isEmpty) {
        _logger.w(
            "Data fetched but with an error from the source: $errorMessage"); // --- LOGGER ---
        _showErrorSnackbar(errorMessage!);
      }
    } catch (e, stackTrace) {
      // --- LOGGER --- Added stackTrace
      _logger.e("Error fetching stories data", e, stackTrace);
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = "Failed to load data. Please try again.";
        });
      }
    }
  }

  Future<void> _toggleStoryBookmark(int storyId) async {
    _logger.i("Toggling bookmark for story ID: $storyId"); // --- LOGGER ---
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
      _logger.w(
          "Cannot toggle story bookmark: User is not logged in."); // --- LOGGER ---
      _showErrorSnackbar("Please log in to manage bookmarks.");
      return;
    }

    final isCurrentlyBookmarked = bookmarks[storyId] ?? false;
    setState(() => bookmarks[storyId] = !isCurrentlyBookmarked);

    try {
      // --- TOGGLE LOGIC REFACTORED ---
      final message = await _bookmarkService.toggleBookmark(
          token: token,
          bookmarkableType: 'story', // Simple API type string
          bookmarkableId: storyId);
      // --- LOGGER ---
      _logger.i(
          "Bookmark toggled successfully for story ID: $storyId. Message: $message");
      _showSuccessSnackbar(message);
    } catch (e, stackTrace) {
      // --- LOGGER --- Added stackTrace
      // --- LOGGER ---
      _logger.e("Error toggling story bookmark for story ID: $storyId", e,
          stackTrace);
      setState(() => bookmarks[storyId] = isCurrentlyBookmarked);
      _showErrorSnackbar("Error updating bookmark. Please try again.");
    }
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    final isNightMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor:
            isNightMode ? Colors.grey[700] : const Color(0xFF009B77),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 80.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2)));
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 80.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3)));
  }

  void _prefetchImages(List<dynamic> items, {int limit = 12}) {
    if (_imagesPrefetched) return;
    _imagesPrefetched = true;
    final urls = items
        .map((e) => e['image']?.toString())
        .where((u) => u != null && u.isNotEmpty)
        .take(limit)
        .toList();
    for (final url in urls) {
      unawaited(_cacheManager.getFileFromCache(url!).then((cached) async {
        if (cached == null) {
          await _cacheManager.downloadFile(url);
        }
      }).catchError((_) {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isNightMode = themeProvider.isDarkMode;
    final authProvider = Provider.of<AuthProvider>(context);
    final bool isUserPremium = authProvider.isPremium;

    return Scaffold(
      backgroundColor: isNightMode ? const Color(0xFF002147) : Colors.white,
      appBar: AppBar(
        backgroundColor:
            isNightMode ? Colors.grey[900] : const Color(0xFF009B77),
        elevation: 0,
        title: const Text('Islamic Stories',
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search stories...',
                prefixIcon: Icon(Icons.search,
                    color: isNightMode ? Colors.white70 : Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isNightMode ? Colors.grey[800] : Colors.grey[200],
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
              ),
              style: TextStyle(
                color: isNightMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _fetchData(forceRefresh: true),
                color: isNightMode ? Colors.white : const Color(0xFF009B77),
                backgroundColor: isNightMode ? Colors.grey[900] : Colors.white,
                child: isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                            color: isNightMode
                                ? Colors.white
                                : const Color(0xFF009B77)))
                    : errorMessage != null && stories.isEmpty
                        ? _buildErrorState(
                            errorMessage!, () => _fetchData(forceRefresh: true))
                        : filteredStories.isEmpty
                            ? _buildEmptyState(
                                isNightMode, searchController.text.isNotEmpty)
                            : GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16.0,
                                  mainAxisSpacing: 16.0,
                                  childAspectRatio: 0.75,
                                ),
                                itemCount: filteredStories.length,
                                itemBuilder: (context, index) {
                                  final story = filteredStories[index];
                                  final storyId =
                                      int.parse(story['id'].toString());
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              StoryDetailPage(story: story),
                                        ),
                                      ).then((_) =>
                                          _fetchData()); // Refresh on return
                                    },
                                    child: _buildStoryCard(
                                      story: story,
                                      isNightMode: isNightMode,
                                      isBookmarked: bookmarks[storyId] ?? false,
                                      onBookmark: () =>
                                          _toggleStoryBookmark(storyId),
                                      isUserPremium: isUserPremium,
                                    ),
                                  );
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... (All build helper methods are unchanged)
  Widget _buildStoryCard({
    required dynamic story,
    required bool isNightMode,
    required bool isBookmarked,
    required VoidCallback onBookmark,
    required bool isUserPremium,
  }) {
    final String title = story['name']?.toString() ?? 'Untitled Story';
    final String? imageUrl = story['image']?.toString();

    final bool isContentPremium =
        (story['is_premium'] == true || story['is_premium'] == 1);
    final bool showPremiumBadge = isContentPremium && !isUserPremium;

    final int episodeCount =
        int.tryParse(story['story_episodes_count']?.toString() ?? '0') ?? 0;

    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isNightMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    width: double.infinity,
                    color: isNightMode ? Colors.grey[800] : Colors.grey[300],
                    child: hasImage
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.fill,
                            placeholder: (context, url) => const Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                            errorWidget: (context, url, error) => Center(
                                child: Icon(Icons.broken_image_outlined,
                                    color: Colors.grey[500])),
                          )
                        : Center(
                            child: Icon(Icons.image_not_supported_outlined,
                                color: Colors.grey[500])),
                  ),
                ),
                if (showPremiumBadge)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('Premium',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isNightMode ? Colors.white : Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$episodeCount Episodes',
                          style: TextStyle(
                              fontSize: 12,
                              color: isNightMode
                                  ? Colors.white70
                                  : Colors.black54)),
                      IconButton(
                        iconSize: 20,
                        icon: Icon(
                            isBookmarked
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: isBookmarked
                                ? (isNightMode
                                    ? Colors.amber.shade600
                                    : const Color(0xFF009B77))
                                : (isNightMode
                                    ? Colors.white54
                                    : Colors.grey.shade600)),
                        onPressed: onBookmark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message, VoidCallback onRetry) {
    final isNightMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(32.0),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.error_outline,
                  color: Colors.redAccent, size: 50),
              const SizedBox(height: 16),
              Text('Load Failed',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isNightMode ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: isNightMode ? Colors.white70 : Colors.grey[600])),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: isNightMode
                          ? Colors.grey[700]!
                          : const Color(0xFF009B77),
                      foregroundColor: Colors.white)),
            ])));
  }

  Widget _buildEmptyState(bool isNightMode, bool isSearching) {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(32.0),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(
                  isSearching
                      ? Icons.search_off_rounded
                      : Icons.auto_stories_outlined,
                  size: 60,
                  color: isNightMode ? Colors.grey[600] : Colors.grey[400]),
              const SizedBox(height: 16),
              Text(isSearching ? 'No Stories Found' : 'No Stories Available',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isNightMode ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              Text(
                  isSearching
                      ? 'Try adjusting your search terms.'
                      : 'There are no stories available right now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: isNightMode ? Colors.white70 : Colors.grey[600])),
            ])));
  }
}
