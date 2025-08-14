import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart'; // --- LOGGER --- Import logger
import 'commentary_detail_page.dart';
import '../../theme_provider.dart';
// --- NEW IMPORTS ---
import '../services/bookmark_service.dart'; // Using the new unified service
import '../services/content_services/data_fetcher.dart';
import '../../providers/auth_provider.dart';

class CommentaryPage extends StatefulWidget {
  const CommentaryPage({super.key});
  @override
  _CommentaryPageState createState() => _CommentaryPageState();
}

class _CommentaryPageState extends State<CommentaryPage> {
  // --- STATE AND SERVICE REFACTOR ---
  final BookmarkService _bookmarkService = BookmarkService();
  List<dynamic> commentaries = [];
  Map<int, bool> bookmarks = {};
  String searchQuery = "";
  bool isLoading = true;
  String? lastError;

  final _logger = Logger(); // --- LOGGER --- Initialize the logger

  @override
  void initState() {
    super.initState();
    _logger.i("CommentaryPage initialized."); // --- LOGGER ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  Future<void> _fetchData({bool forceRefresh = false}) async {
    if (!mounted) return;
    _logger.i(
        "Fetching commentaries... forceRefresh: $forceRefresh"); // --- LOGGER ---
    setState(() {
      isLoading = true;
      if (forceRefresh) lastError = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
      _logger.w(
          "Cannot fetch commentaries: User is not logged in (token is null)."); // --- LOGGER ---
      if (mounted) {
        setState(() {
          isLoading = false;
          lastError = "Please log in to view commentaries.";
          commentaries = [];
          bookmarks = {};
        });
      }
      return;
    }

    try {
      // --- FETCH LOGIC REFACTORED ---
      _logger.d(
          "Fetching commentaries and bookmarks in parallel."); // --- LOGGER ---
      final contentFuture = fetchAndCacheContent(
        apiEndpoint: 'commentaries',
        cacheKey: 'commentaries_cache_v2',
        token: token,
        forceRefresh: forceRefresh,
      );
      final bookmarksFuture = _bookmarkService.fetchAllBookmarks(token);

      final contentResult = await contentFuture;
      final allBookmarks = await bookmarksFuture;

      final bookmarkedIds = allBookmarks
          .where((b) => b['bookmarkable_type'].endsWith('Commentary'))
          // --- FIX --- Changed unsafe cast to robust parsing
          .map((b) => int.parse(b['bookmarkable_id'].toString()))
          .toSet();

      if (!mounted) return;
      setState(() {
        commentaries = contentResult['data'];
        lastError = contentResult['error'];
        bookmarks = {
          for (var item in commentaries)
            int.parse(item['id'].toString()):
                bookmarkedIds.contains(int.parse(item['id'].toString()))
        };
        isLoading = false;
      });
      // --- LOGGER ---
      _logger.i(
          "Successfully fetched ${commentaries.length} commentaries and ${bookmarks.length} commentary bookmarks.");

      if (lastError != null && commentaries.isEmpty) {
        _logger.w(
            "Data fetched but with an error from the source: $lastError"); // --- LOGGER ---
        _showErrorSnackbar(lastError!);
      }
    } catch (e, stackTrace) {
      // --- LOGGER --- Added stackTrace
      _logger.e("Error fetching commentaries data", e, stackTrace);
      if (mounted) {
        setState(() {
          isLoading = false;
          lastError = "Failed to load data. Please try again.";
        });
      }
    }
  }

  Future<void> _handleToggleBookmark(int commentaryId) async {
    _logger.i(
        "Toggling bookmark for commentary ID: $commentaryId"); // --- LOGGER ---
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
      _logger.w(
          "Cannot toggle bookmark: User is not logged in."); // --- LOGGER ---
      _showErrorSnackbar("Please log in to manage bookmarks.");
      return;
    }

    final isCurrentlyBookmarked = bookmarks[commentaryId] ?? false;
    setState(() => bookmarks[commentaryId] = !isCurrentlyBookmarked);

    try {
      // --- TOGGLE LOGIC REFACTORED ---
      final message = await _bookmarkService.toggleBookmark(
        token: token,
        bookmarkableType: 'commentary',
        bookmarkableId: commentaryId,
      );
      _logger.i(
          "Bookmark toggled successfully for commentary ID: $commentaryId. Message: $message"); // --- LOGGER ---
      _showSuccessSnackbar(message);
    } catch (e, stackTrace) {
      // --- LOGGER --- Added stackTrace
      _logger.e("Error updating bookmark for commentary ID: $commentaryId", e,
          stackTrace); // --- LOGGER ---
      setState(() => bookmarks[commentaryId] = isCurrentlyBookmarked);
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
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2)));
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isNightMode = themeProvider.isDarkMode;
    final authProvider = Provider.of<AuthProvider>(context);
    final bool isUserPremium = authProvider.isPremium;

    final filteredData = commentaries.where((item) {
      final title = item['title']?.toString().toLowerCase() ?? '';
      final description = item['description']?.toString().toLowerCase() ?? '';
      final query = searchQuery.toLowerCase();
      return title.contains(query) || description.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: isNightMode ? const Color(0xFF002147) : Colors.grey[100],
      appBar: AppBar(
        backgroundColor:
            isNightMode ? Colors.grey[900] : const Color(0xFF009B77),
        elevation: 0,
        title: const Text('Commentaries',
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
                hintText: 'Search commentaries...',
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
                    borderSide: BorderSide.none),
              ),
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
                    child: commentaries.isEmpty && lastError != null
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
                                  final commentary = filteredData[index];
                                  final commentaryId =
                                      int.parse(commentary['id'].toString());
                                  return _buildCommentaryItem(
                                    context,
                                    commentary,
                                    commentaryId,
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

  Widget _buildCommentaryItem(BuildContext context, dynamic commentary,
      int commentaryId, bool isNightMode, bool isUserPremium) {
    final isBookmarked = bookmarks[commentaryId] ?? false;
    final bool isContentPremium =
        (commentary['is_premium'] == true || commentary['is_premium'] == 1);
    final bool showPremiumIcon = isContentPremium && !isUserPremium;
    final String title =
        commentary['title']?.toString() ?? 'Untitled Commentary';
    final String description =
        commentary['description']?.toString() ?? 'No description available.';
    final String? imageUrl = commentary['image']?.toString();

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
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            _logger.d(
                "Navigating to CommentaryDetailPage for ID: $commentaryId"); // --- LOGGER ---
            Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            CommentaryDetailPage(commentary: commentary)))
                .then((_) => _fetchData());
          },
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: _buildLeadingImage(imageUrl, isNightMode),
            title: Text(title,
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
                  onPressed: () => _handleToggleBookmark(commentaryId),
                  tooltip: isBookmarked ? "Remove bookmark" : "Add bookmark"),
            ]),
          ),
        ),
      ),
    );
  }

  // ... The rest of the build helper methods are unchanged
  Widget _buildLeadingImage(String? imageUrl, bool isNightMode) {
    const double size = 50.0;
    final placeholderColor =
        isNightMode ? Colors.grey[800]! : Colors.grey[300]!;
    Widget placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: placeholderColor, borderRadius: BorderRadius.circular(8.0)),
      child: Icon(Icons.comment_bank_outlined,
          color: isNightMode ? Colors.white54 : Colors.grey[600], size: 24),
    );

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => placeholder,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: size,
              height: size,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
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
              Text(
                  'Try adjusting your search terms to find what you are looking for.',
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
            Icon(Icons.comment_bank_outlined,
                size: 70,
                color: isNightMode ? Colors.grey[600] : Colors.grey[400]),
            const SizedBox(height: 20),
            Text('No Commentaries Found',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isNightMode ? Colors.white : Colors.black87)),
            const SizedBox(height: 10),
            Text('There are no commentaries available right now.',
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
