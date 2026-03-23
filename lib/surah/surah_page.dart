import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart'; // --- LOGGER --- Import logger
import 'surah_detail_page.dart';
import '../../theme_provider.dart';
// --- NEW IMPORTS ---
import '../services/bookmark_service.dart'; // Using the new unified service
import '../services/content_services/data_fetcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/content_cache_provider.dart';
import '../../providers/bookmark_provider.dart';

class SurahPage extends StatefulWidget {
  const SurahPage({super.key});
  @override
  _SurahPageState createState() => _SurahPageState();
}

class _SurahPageState extends State<SurahPage> {
  // --- STATE AND SERVICE REFACTOR ---
  List<dynamic> surahs = [];
  String searchQuery = "";
  bool isLoading = true;
  String? lastError;

  final _logger = Logger(); // --- LOGGER --- Initialize the logger

  @override
  void initState() {
    super.initState();
    _logger.i("SurahPage initialized."); // --- LOGGER ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  Future<void> _fetchData({bool forceRefresh = false}) async {
    if (!mounted) return;
    _logger.i("Fetching data... forceRefresh: $forceRefresh"); // --- LOGGER ---
    final cacheProvider =
        Provider.of<ContentCacheProvider>(context, listen: false);

    // Quick return with cached surahs.
    if (!forceRefresh && cacheProvider.hasData('surahs')) {
      final cached = cacheProvider.getData('surahs');
      setState(() {
        surahs = cached;
        lastError = null;
        isLoading = false;
      });
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
          "Cannot fetch surahs: User is not logged in (token is null)."); // --- LOGGER ---
      if (mounted) {
        setState(() {
          isLoading = false;
          lastError = "Please log in to view Surahs.";
          surahs = [];
        });
      }
      return;
    }

    try {
      _logger.d("Fetching surahs and bookmarks in parallel."); // --- LOGGER ---
      final contentFuture = fetchAndCacheContent(
        apiEndpoint: 'surahs',
        cacheKey: 'surahs_cache_v2',
        token: token,
        forceRefresh: forceRefresh,
      );

      final result = await contentFuture;
      if (!mounted) return;
      
      setState(() {
        surahs = result['data'];
        lastError = result['error'];
        isLoading = false;
      });

      // Cache for reuse.
      cacheProvider.setData('surahs', surahs);
      // --- LOGGER ---
      _logger.i(
          "Successfully fetched ${surahs.length} surahs.");

      if (lastError != null && surahs.isEmpty) {
        _logger.w(
            "Data fetched but with an error from the source: $lastError"); // --- LOGGER ---
        if (mounted) _showErrorSnackbar(lastError!);
      }
    } catch (e, stackTrace) {
      // --- LOGGER --- Added stackTrace
      _logger.e("Error in _fetchData", e, stackTrace);
      if (mounted) {
        setState(() {
          isLoading = false;
          lastError = "Failed to load data. Please try again.";
        });
      }
    }
  }

  Future<void> _toggleBookmark(int surahId) async {
    _logger.i("Toggling bookmark for surah ID: $surahId");
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookmarkProvider =
        Provider.of<BookmarkProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
      _showErrorSnackbar("Please log in to manage bookmarks.");
      return;
    }

    try {
      await bookmarkProvider.toggleBookmark(
        token: token,
        type: 'surah',
        id: surahId,
      );
      if (!mounted) return;
      _showSuccessSnackbar(bookmarkProvider.isBookmarked('surah', surahId)
          ? "Bookmark added successfully"
          : "Bookmark removed successfully");
    } catch (e, stackTrace) {
      if (!mounted) return;
      _logger.e("Error toggling bookmark for surah ID: $surahId", e, stackTrace);
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
        margin: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 20.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2)));
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 20.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isNightMode = themeProvider.isDarkMode;
    final authProvider = Provider.of<AuthProvider>(context);
    final bool isUserPremium = authProvider.isPremium;

    final filteredData = surahs.where((surah) {
      final name = surah['name']?.toString().toLowerCase() ?? '';
      final description = surah['description']?.toString().toLowerCase() ?? '';
      final query = searchQuery.toLowerCase();
      return name.contains(query) || description.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: isNightMode ? const Color(0xFF002147) : Colors.grey[100],
      appBar: AppBar(
        backgroundColor:
            isNightMode ? Colors.grey[900] : const Color(0xFF009B77),
        elevation: 0,
        title: const Text('Objective of Surahs',
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
                hintText: 'Search surahs',
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
            child: Consumer<BookmarkProvider>(
              builder: (context, bookmarkProvider, child) {
                return isLoading
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
                        child: surahs.isEmpty && lastError != null
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
                                      final surah = filteredData[index];
                                      final surahId =
                                          int.parse(surah['id'].toString());
                                      return _buildSurahItem(
                                        context,
                                        surah,
                                        surahId,
                                        index,
                                        isNightMode,
                                        isUserPremium,
                                        bookmarkProvider,
                                      );
                                    },
                                  ),
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahItem(
      BuildContext context,
      dynamic surah,
      int surahId,
      int index,
      bool isNightMode,
      bool isUserPremium,
      BookmarkProvider bookmarkProvider) {
    final isBookmarked = bookmarkProvider.isBookmarked('surah', surahId);

    final bool isContentPremium =
        (surah['is_premium'] == true || surah['is_premium'] == 1);
    final bool showPremiumIcon = isContentPremium && !isUserPremium;

    final String name = surah['name']?.toString() ?? 'Unnamed Surah';
    final String description =
        surah['description']?.toString() ?? 'No description available.';

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
            Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => SurahDetailPage(surah: surah)))
                .then((_) => _fetchData());
          },
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: CircleAvatar(
              backgroundColor:
                  isNightMode ? Colors.teal.shade800 : Colors.teal.shade50,
              child: Text(
                '${surah['number'] ?? index + 1}',
                style: TextStyle(
                  color: isNightMode ? Colors.white70 : Colors.teal.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              name,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isNightMode ? Colors.white : Colors.black87),
            ),
            subtitle: Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: isNightMode ? Colors.white70 : Colors.grey[600],
                  fontSize: 13),
            ),
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
                  size: 24,
                ),
                onPressed: () => _toggleBookmark(surahId),
                tooltip: isBookmarked ? "Remove bookmark" : "Add bookmark",
              ),
            ]),
          ),
        ),
      ),
    );
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
                  'Try adjusting your search terms to find the surah you are looking for.',
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
            Icon(Icons.mosque_outlined,
                size: 70,
                color: isNightMode ? Colors.grey[600] : Colors.grey[400]),
            const SizedBox(height: 20),
            Text('No Surahs Found',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isNightMode ? Colors.white : Colors.black87)),
            const SizedBox(height: 10),
            Text(
                'There are no surahs available right now.\nTry refreshing or check back later!',
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
