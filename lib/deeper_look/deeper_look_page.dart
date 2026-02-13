import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart'; // --- LOGGER --- Import logger
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'deeper_look_detail_page.dart';
import '../../theme_provider.dart';
// --- NEW IMPORTS ---
import '../services/bookmark_service.dart'; // Using the new unified service
import '../services/content_services/data_fetcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/content_cache_provider.dart';

class DeeperLookPage extends StatefulWidget {
  const DeeperLookPage({super.key});
  @override
  _DeeperLookPageState createState() => _DeeperLookPageState();
}

class _DeeperLookPageState extends State<DeeperLookPage> {
  // --- STATE AND SERVICE REFACTOR ---
  final BookmarkService _bookmarkService = BookmarkService();
  List<dynamic> deeperLooks = [];
  Map<int, bool> bookmarks = {};
  String searchQuery = "";
  bool isLoading = true;
  String? lastError;
  bool _imagesPrefetched = false;
  final DefaultCacheManager _cacheManager = DefaultCacheManager();

  final _logger = Logger(); // --- LOGGER --- Initialize the logger

  @override
  void initState() {
    super.initState();
    _logger.i("DeeperLookPage initialized."); // --- LOGGER ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  Future<void> _fetchData({bool forceRefresh = false}) async {
    if (!mounted) return;
    _logger.i(
        "Fetching Deeper Looks... forceRefresh: $forceRefresh"); // --- LOGGER ---
    final cacheProvider =
        Provider.of<ContentCacheProvider>(context, listen: false);

    if (!forceRefresh && cacheProvider.hasData('deeperLooks')) {
      final cached = cacheProvider.getData('deeperLooks');
      setState(() {
        deeperLooks = cached;
        lastError = null;
        isLoading = false;
      });
      _prefetchImages(cached);
      return;
    }

    setState(() {
      isLoading = true;
      if (forceRefresh) lastError = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
      _logger.w(
          "Cannot fetch deeper looks: User is not logged in (token is null)."); // --- LOGGER ---
      if (mounted) {
        setState(() {
          isLoading = false;
          lastError = "Please log in to view this content.";
          deeperLooks = [];
          bookmarks = {};
        });
      }
      return;
    }

    try {
      // --- FETCH LOGIC REFACTORED ---
      _logger.d(
          "Fetching deeper looks and bookmarks in parallel."); // --- LOGGER ---
      final contentFuture = fetchAndCacheContent(
        apiEndpoint: 'deeper-looks',
        cacheKey: 'deeper_looks_cache_v2',
        token: token,
        forceRefresh: forceRefresh,
      );
      final bookmarksFuture = _bookmarkService.fetchAllBookmarks(token);

      final result = await contentFuture;
      final allBookmarks = await bookmarksFuture;

      final bookmarkedIds = allBookmarks
          .where((b) => b['bookmarkable_type'].endsWith('DeeperLook'))
          // --- FIX --- Changed unsafe cast to robust parsing
          .map((b) => int.parse(b['bookmarkable_id'].toString()))
          .toSet();

      if (!mounted) return;
      setState(() {
        deeperLooks = result['data'];
        lastError = result['error'];
        bookmarks = {
          for (var item in deeperLooks)
            int.parse(item['id'].toString()):
                bookmarkedIds.contains(int.parse(item['id'].toString()))
        };
        isLoading = false;
      });

      cacheProvider.setData('deeperLooks', deeperLooks);
      _prefetchImages(deeperLooks);
      // --- LOGGER ---
      _logger.i(
          "Successfully fetched ${deeperLooks.length} deeper looks and ${bookmarks.length} bookmarks.");

      if (lastError != null && deeperLooks.isEmpty) {
        _logger.w(
            "Data fetched but with an error from the source: $lastError"); // --- LOGGER ---
        _showErrorSnackbar(lastError!);
      }
    } catch (e, stackTrace) {
      // --- LOGGER --- Added stackTrace
      _logger.e("Error fetching deeper looks data", e, stackTrace);
      if (mounted) {
        setState(() {
          isLoading = false;
          lastError = "Failed to load data. Please try again.";
        });
      }
    }
  }

  Future<void> _toggleBookmark(int deeperLookId) async {
    _logger.i(
        "Toggling bookmark for Deeper Look ID: $deeperLookId"); // --- LOGGER ---
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
      _logger.w(
          "Cannot toggle bookmark: User is not logged in."); // --- LOGGER ---
      _showErrorSnackbar("Please log in to manage bookmarks.");
      return;
    }

    final isCurrentlyBookmarked = bookmarks[deeperLookId] ?? false;
    setState(() => bookmarks[deeperLookId] = !isCurrentlyBookmarked);

    try {
      // --- TOGGLE LOGIC REFACTORED ---
      final message = await _bookmarkService.toggleBookmark(
          token: token,
          bookmarkableType: 'deeper_look', // Simple API type string
          bookmarkableId: deeperLookId);
      // --- LOGGER ---
      _logger.i(
          "Bookmark toggled successfully for Deeper Look ID: $deeperLookId. Message: $message");
      _showSuccessSnackbar(message);
    } catch (e, stackTrace) {
      // --- LOGGER --- Added stackTrace
      // --- LOGGER ---
      _logger.e("Error toggling bookmark for Deeper Look ID: $deeperLookId", e,
          stackTrace);
      setState(() => bookmarks[deeperLookId] = isCurrentlyBookmarked);
      _showErrorSnackbar("Error updating bookmark. Please try again.");
    }
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: themeProvider.isDarkMode
        ? Colors.grey[700]
        : const Color(0xFF009B77),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 80.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2)));
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
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

    final filteredData = deeperLooks.where((item) {
      final name = item['name']?.toString().toLowerCase() ?? '';
      final description = item['description']?.toString().toLowerCase() ?? '';
      final query = searchQuery.toLowerCase();
      return name.contains(query) || description.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: isNightMode ? const Color(0xFF002147) : Colors.grey[100],
      appBar: AppBar(
        backgroundColor:
            isNightMode ? Colors.grey[900] : const Color(0xFF009B77),
        elevation: 0,
        title: const Text('Deeper Looks',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value),
              style:
                  TextStyle(color: isNightMode ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search,
                      color: isNightMode ? Colors.white70 : Colors.grey[600]),
                  hintText: 'Search deeper looks...',
                  hintStyle: TextStyle(
                      color: isNightMode ? Colors.white70 : Colors.grey[600]),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  fillColor: isNightMode ? Colors.grey[850] : Colors.white,
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none)),
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        color: isNightMode
                            ? Colors.white
                            : const Color(0xFF009B77)))
                : RefreshIndicator(
                    onRefresh: () => _fetchData(forceRefresh: true),
                    color: isNightMode ? Colors.white : const Color(0xFF009B77),
                    backgroundColor:
                        isNightMode ? Colors.grey[900] : Colors.white,
                    child: deeperLooks.isEmpty && lastError != null
                        ? _buildErrorState(lastError!,
                            () => _fetchData(forceRefresh: true), isNightMode)
                        : filteredData.isEmpty
                            ? _buildEmptyState(
                                () => _fetchData(forceRefresh: true),
                                isNightMode,
                                isSearchActive: searchQuery.isNotEmpty)
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 16),
                                itemCount: filteredData.length,
                                itemBuilder: (context, index) {
                                  final deeperLook = filteredData[index];
                                  final deeperLookId =
                                      int.parse(deeperLook['id'].toString());
                                  return _buildDeeperLookItem(
                                    context,
                                    deeperLook,
                                    deeperLookId,
                                    isNightMode,
                                    isUserPremium,
                                  );
                                },
                              ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeeperLookItem(BuildContext context, dynamic deeperLook,
      int deeperLookId, bool isNightMode, bool isUserPremium) {
    final isBookmarked = bookmarks[deeperLookId] ?? false;
    final bool isContentPremium =
        (deeperLook['is_premium'] == true || deeperLook['is_premium'] == 1);
    final bool showPremiumIcon = isContentPremium && !isUserPremium;
    final String name = deeperLook['name']?.toString() ?? 'Unnamed Deeper Look';
    final String description =
        deeperLook['description']?.toString() ?? 'No description available.';
    final String? imageUrl = deeperLook['image']?.toString();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
          color: isNightMode ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(isNightMode ? 0.15 : 0.07),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ]),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            _logger.d(
                "Navigating to DeeperLookDetailPage for ID: $deeperLookId"); // --- LOGGER ---
            Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            DeeperLookDetailPage(deeperLook: deeperLook)))
                .then((_) => _fetchData());
          },
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: _buildLeadingImage(imageUrl, isNightMode),
            title: Text(name,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isNightMode ? Colors.white : Colors.black87)),
            subtitle: Text(description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: isNightMode ? Colors.white70 : Colors.grey[600],
                    fontSize: 13)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (showPremiumIcon)
                Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: Icon(Icons.workspace_premium,
                        color: isNightMode
                            ? Colors.amber.shade400
                            : Colors.amber.shade700,
                        size: 20)),
              IconButton(
                  icon: Icon(
                      isBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: isBookmarked
                          ? (isNightMode
                              ? Colors.amber.shade400
                              : const Color(0xFF009B77))
                          : (isNightMode ? Colors.white54 : Colors.grey[500]),
                      size: 24),
                  onPressed: () => _toggleBookmark(deeperLookId),
                  tooltip: isBookmarked ? "Remove bookmark" : "Add bookmark"),
            ]),
          ),
        ),
      ),
    );
  }

  // ... (The rest of the build helper methods are unchanged)
  Widget _buildLeadingImage(String? imageUrl, bool isNightMode) {
    const double size = 50.0;
    final placeholderColor =
        isNightMode ? Colors.grey[800]! : Colors.grey[300]!;
    Widget placeholder = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: placeholderColor, borderRadius: BorderRadius.circular(8.0)),
        child: Icon(Icons.video_library_outlined,
            color: isNightMode ? Colors.white54 : Colors.grey[600], size: 24));
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => SizedBox(
            width: size,
            height: size,
            child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2.0)),
          ),
          errorWidget: (context, url, error) => placeholder,
        ),
      );
    }
    return placeholder;
  }

  Widget _buildErrorState(
      String message, VoidCallback onRetry, bool isNightMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 60),
            const SizedBox(height: 20),
            Text('Load Failed',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isNightMode ? Colors.white : Colors.black87)),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    color: isNightMode ? Colors.white70 : Colors.grey[700])),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.0),
                  child: Text('Retry', style: TextStyle(fontSize: 16))),
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isNightMode ? Colors.grey[700] : const Color(0xFF009B77),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(VoidCallback onRetry, bool isNightMode,
      {bool isSearchActive = false}) {
    if (isSearchActive) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 70,
                  color: isNightMode ? Colors.grey[600] : Colors.grey[400]),
              const SizedBox(height: 20),
              Text('No Results Found',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isNightMode ? Colors.white : Colors.black87)),
              const SizedBox(height: 10),
              Text('Try adjusting your search terms.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15,
                      color: isNightMode ? Colors.white70 : Colors.grey[700])),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined,
                size: 70,
                color: isNightMode ? Colors.grey[600] : Colors.grey[400]),
            const SizedBox(height: 20),
            Text('No Deeper Looks Found',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isNightMode ? Colors.white : Colors.black87)),
            const SizedBox(height: 10),
            Text('There are no deeper looks available right now.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    color: isNightMode ? Colors.white70 : Colors.grey[700])),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.0),
                  child: Text('Refresh', style: TextStyle(fontSize: 16))),
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isNightMode ? Colors.grey[700] : const Color(0xFF009B77),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
            ),
          ],
        ),
      ),
    );
  }
}
