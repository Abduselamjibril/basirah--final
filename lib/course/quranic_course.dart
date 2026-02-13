import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'course_detail_page.dart';
import '../../theme_provider.dart';
// --- NEW IMPORTS ---
import '../services/bookmark_service.dart'; // Using the new unified service
import '../services/content_services/data_fetcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/content_cache_provider.dart';

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});
  @override
  _CoursesPageState createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  // --- STATE AND SERVICE REFACTOR ---
  final BookmarkService _bookmarkService = BookmarkService();
  List<dynamic> courses = [];
  List<dynamic> filteredCourses = [];
  Map<int, bool> bookmarks = {};
  bool isLoading = true;
  String? errorMessage;
  TextEditingController searchController = TextEditingController();
  String? selectedCategory;
  bool _imagesPrefetched = false;
  final DefaultCacheManager _cacheManager = DefaultCacheManager();

  final ScrollController _scrollController = ScrollController();
  Timer? _scrollDebounce;
  bool _isAutoScrolling = false;

  final _logger = Logger();

  // --- LAYOUT CONSTANTS ---
  static const double _childAspectRatio = 0.75;
  static const double _gridHorizontalPadding = 16.0;
  static const double _crossAxisSpacing = 16.0;
  static const double _mainAxisSpacing = 16.0;

  @override
  void initState() {
    super.initState();
    _logger.i("CoursesPage initialized.");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
    searchController.addListener(_filterCourses);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollDebounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchData({bool forceRefresh = false}) async {
    if (!mounted) return;
    _logger.i("Fetching courses... forceRefresh: $forceRefresh");
    final cacheProvider =
        Provider.of<ContentCacheProvider>(context, listen: false);

    // Serve cached data instantly when available and not forcing refresh.
    if (!forceRefresh && cacheProvider.hasData('courses')) {
      final cached = cacheProvider.getData('courses');
      setState(() {
        courses = cached;
        filteredCourses = cached;
        isLoading = false;
        errorMessage = null;
      });
      _prefetchImages(cached);
      _filterCourses();
      return;
    }

    setState(() {
      isLoading = true;
      if (forceRefresh) errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
      _logger.w("Cannot fetch courses: User is not logged in (token is null).");
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = "Please log in to view courses.";
          courses = [];
          bookmarks = {};
        });
      }
      return;
    }

    try {
      // --- FETCH LOGIC REFACTORED ---
      _logger.d("Fetching courses and bookmarks in parallel.");
      final contentFuture = fetchAndCacheContent(
        apiEndpoint: 'courses',
        cacheKey: 'courses_cache',
        token: token,
        forceRefresh: forceRefresh,
      );
      final bookmarksFuture = _bookmarkService.fetchAllBookmarks(token);

      final contentResult = await contentFuture;
      final allBookmarks = await bookmarksFuture;

      final bookmarkedIds = allBookmarks
          .where((b) => b['bookmarkable_type'].endsWith('Course'))
          .map((b) => int.parse(b['bookmarkable_id'].toString()))
          .toSet();

      if (!mounted) return;
      setState(() {
        courses = contentResult['data'];
        errorMessage = contentResult['error'];
        bookmarks = {
          for (var item in courses)
            int.parse(item['id'].toString()):
                bookmarkedIds.contains(int.parse(item['id'].toString()))
        };
        if (uniqueCategories.isNotEmpty && selectedCategory == null) {
          selectedCategory = uniqueCategories.first;
        }
        isLoading = false;
        _filterCourses();
      });

      // Cache for other tabs and subsequent opens.
      cacheProvider.setData('courses', courses);
      _prefetchImages(courses);

      _logger.i(
          "Successfully fetched ${courses.length} courses and ${bookmarks.length} course bookmarks.");

      if (errorMessage != null && courses.isEmpty) {
        _logger
            .w("Data fetched but with an error from the source: $errorMessage");
        _showErrorSnackbar(errorMessage!);
      }
    } catch (e, stackTrace) {
      _logger.e("Error fetching courses data", e, stackTrace);
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = "Failed to load data. Please try again.";
        });
      }
    }
  }

  void _prefetchImages(List<dynamic> items, {int limit = 12}) {
    if (_imagesPrefetched) return;
    _imagesPrefetched = true;
    final urls = items
        .map((e) => e['image_path']?.toString())
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

  Future<void> _toggleCourseBookmark(int courseId) async {
    _logger.i("Toggling bookmark for course ID: $courseId");
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
      _logger.w("Cannot toggle course bookmark: User is not logged in.");
      _showErrorSnackbar("Please log in to manage bookmarks.");
      return;
    }

    final isCurrentlyBookmarked = bookmarks[courseId] ?? false;
    setState(() => bookmarks[courseId] = !isCurrentlyBookmarked);

    try {
      // --- TOGGLE LOGIC REFACTORED ---
      final message = await _bookmarkService.toggleBookmark(
          token: token,
          bookmarkableType: 'course', // Simple API type string
          bookmarkableId: courseId);
      _logger.i(
          "Bookmark toggled successfully for course ID: $courseId. Message: $message");
      _showSuccessSnackbar(message);
    } catch (e, stackTrace) {
      _logger.e("Error toggling course bookmark for course ID: $courseId", e,
          stackTrace);
      setState(() => bookmarks[courseId] = isCurrentlyBookmarked);
      _showErrorSnackbar("Error updating bookmark. Please try again.");
    }
  }

  void _onScroll() {
    if (_isAutoScrolling || !_scrollController.hasClients || courses.isEmpty)
      return;
    if (_scrollDebounce?.isActive ?? false) _scrollDebounce!.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 50), () {
      final screenWidth = MediaQuery.of(context).size.width;
      // --- REFACTORED to use constants ---
      final cardWidth =
          (screenWidth - (2 * _gridHorizontalPadding) - _crossAxisSpacing) / 2;
      final cardHeight = cardWidth / _childAspectRatio;
      final rowHeight = cardHeight + _mainAxisSpacing;

      List<dynamic> currentViewCourses = courses.where((course) {
        return (selectedCategory == null ||
            (course['category']?.toString() ?? 'Uncategorized') ==
                selectedCategory);
      }).toList();

      final firstVisibleItemIndex =
          (_scrollController.offset / rowHeight).floor() * 2;

      if (firstVisibleItemIndex >= 0 &&
          firstVisibleItemIndex < currentViewCourses.length) {
        final newCategory =
            currentViewCourses[firstVisibleItemIndex]['category']?.toString() ??
                'Uncategorized';
        if (newCategory != selectedCategory) {
          _logger.d(
              "Category changed via scroll from '$selectedCategory' to '$newCategory'");
          setState(() => selectedCategory = newCategory);
        }
      }
    });
  }

  void _onCategoryTapped(String category) {
    _logger.d("Category tapped: '$category'");
    searchController.clear();

    final targetIndex = courses.indexWhere(
        (c) => (c['category']?.toString() ?? 'Uncategorized') == category);

    if (targetIndex != -1) {
      final screenWidth = MediaQuery.of(context).size.width;
      // --- REFACTORED to use constants ---
      final cardWidth =
          (screenWidth - (2 * _gridHorizontalPadding) - _crossAxisSpacing) / 2;
      final cardHeight = cardWidth / _childAspectRatio;
      final rowHeight = cardHeight + _mainAxisSpacing;
      final targetRow = (targetIndex / 2).floor();
      final scrollOffset = targetRow * rowHeight;

      setState(() {
        selectedCategory = category;
        _filterCourses();
      });

      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        _isAutoScrolling = true;
        _scrollController
            .animateTo(
              scrollOffset,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            )
            .whenComplete(() => _isAutoScrolling = false);
      }
    }
  }

  List<String> get uniqueCategories {
    if (courses.isEmpty) return [];
    return courses
        .map((course) => course['category']?.toString() ?? 'Uncategorized')
        .toSet()
        .toList()
      ..sort();
  }

  void _filterCourses() {
    final query = searchController.text.toLowerCase();
    _logger
        .d("Filtering courses. Category: '$selectedCategory', Query: '$query'");
    setState(() {
      filteredCourses = courses.where((course) {
        final title = course['name']?.toString().toLowerCase() ?? '';
        final description =
            course['description']?.toString().toLowerCase() ?? '';
        final categoryMatch = selectedCategory == null ||
            (course['category']?.toString() ?? 'Uncategorized') ==
                selectedCategory;
        final searchMatch = query.isEmpty ||
            title.contains(query) ||
            description.contains(query);
        return categoryMatch && searchMatch;
      }).toList();
    });
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isNightMode = themeProvider.isDarkMode;
    final categories = uniqueCategories;

    final authProvider = Provider.of<AuthProvider>(context);
    final bool isUserPremium = authProvider.isPremium;

    return Scaffold(
      backgroundColor: isNightMode ? const Color(0xFF002147) : Colors.white,
      appBar: AppBar(
        backgroundColor:
            isNightMode ? Colors.grey[900] : const Color(0xFF009B77),
        elevation: 0,
        title: const Text('Quranic Courses',
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _gridHorizontalPadding),
        child: Column(
          children: [
            if (!isLoading && categories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: SizedBox(
                  height: 50,
                  child: _buildCategorySelector(categories, isNightMode),
                ),
              ),
            if (!isLoading && categories.isNotEmpty) const SizedBox(height: 16),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search courses...',
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
              // --- PULL-TO-REFRESH ---
              // This RefreshIndicator widget handles the "pull to refresh"
              // functionality for the entire course grid.
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
                    : errorMessage != null && courses.isEmpty
                        ? _buildErrorState(
                            errorMessage!, () => _fetchData(forceRefresh: true))
                        : filteredCourses.isEmpty
                            ? _buildEmptyState(
                                isNightMode, searchController.text.isNotEmpty)
                            : GridView.builder(
                                controller: _scrollController,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: _crossAxisSpacing,
                                  mainAxisSpacing: _mainAxisSpacing,
                                  childAspectRatio: _childAspectRatio,
                                ),
                                itemCount: filteredCourses.length,
                                itemBuilder: (context, index) {
                                  final course = filteredCourses[index];
                                  final courseId =
                                      int.parse(course['id'].toString());
                                  return GestureDetector(
                                    onTap: () {
                                      _logger.d(
                                          "Navigating to CourseDetailPage for ID: $courseId");
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              CourseDetailPage(course: course),
                                        ),
                                      ).then((_) =>
                                          _fetchData(forceRefresh: true));
                                    },
                                    child: _buildCourseCard(
                                      course: course,
                                      isNightMode: isNightMode,
                                      isBookmarked:
                                          bookmarks[courseId] ?? false,
                                      onBookmark: () =>
                                          _toggleCourseBookmark(courseId),
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

  Widget _buildCategorySelector(List<String> categories, bool isNightMode) {
    return Row(
      children: categories.asMap().entries.map((entry) {
        int idx = entry.key;
        String category = entry.value;
        final isSelected = selectedCategory == category;
        return Expanded(
          child: GestureDetector(
            onTap: () => _onCategoryTapped(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: EdgeInsets.only(
                  left: idx == 0 ? 0 : 4,
                  right: idx == categories.length - 1 ? 0 : 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isNightMode ? Colors.grey[700] : const Color(0xFF009B77))
                    : (isNightMode ? Colors.grey[800] : Colors.grey[200]),
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? Border.all(color: Colors.white24, width: 1)
                    : null,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    category,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isNightMode ? Colors.white70 : Colors.black54),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCourseCard({
    required dynamic course,
    required bool isNightMode,
    required bool isBookmarked,
    required VoidCallback onBookmark,
    required bool isUserPremium,
  }) {
    final String title = course['name']?.toString() ?? 'Untitled Course';
    final String? imageUrl = course['image_path']?.toString();

    final bool isContentPremium =
        (course['is_premium'] == true || course['is_premium'] == 1);
    final bool showPremiumBadge = isContentPremium && !isUserPremium;

    final int episodeCount =
        int.tryParse(course['episodes_count'].toString()) ?? 0;
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    color: isNightMode ? Colors.grey[800] : Colors.grey[300],
                    child: hasImage
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isNightMode ? Colors.white : Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('$episodeCount Episodes',
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                isNightMode ? Colors.white70 : Colors.black54)),
                    IconButton(
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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
                    foregroundColor: Colors.white),
              ),
            ])));
  }

  Widget _buildEmptyState(bool isNightMode, bool isSearchActive) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                isSearchActive
                    ? Icons.search_off_rounded
                    : Icons.school_outlined,
                size: 60,
                color: isNightMode ? Colors.grey[600] : Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No Courses Found',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isNightMode ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text(
                isSearchActive
                    ? 'No courses match your search in this category.'
                    : 'No courses are available in this category.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: isNightMode ? Colors.white70 : Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
