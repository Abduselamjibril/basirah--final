import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

// Your Imports
import '../theme_provider.dart';
import '../course/course_detail_page.dart' as CoursePage;
import '../surah/surah_detail_page.dart';
import '../story/story_detail_page.dart' as StoryPage;
import '../deeper_look/deeper_look_detail_page.dart';
import '../Commentary/commentary_detail_page.dart';
import '../providers/auth_provider.dart';
// --- NEW IMPORT ---
import '../providers/content_cache_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // --- STATE REMOVED ---
  // All data lists and isLoading booleans are now in ContentCacheProvider.

  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _heroImagesPrefetched = false;
  final DefaultCacheManager _cacheManager = DefaultCacheManager();

  // --- initState is now much simpler ---
  @override
  void initState() {
    super.initState();
    // The initial fetch is now handled by MainScreen.
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- _fetchAllData is now a simple call to the provider ---
  Future<void> _fetchAllData({bool forceRefresh = false}) async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to refresh content.'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 70.0),
        ),
      );
      return;
    }

    // Call the central provider to refresh data for the whole app.
    await Provider.of<ContentCacheProvider>(context, listen: false)
        .fetchAllContent(token: token, forceRefresh: forceRefresh);

    if (mounted && forceRefresh) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Content refreshed successfully!'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 70.0),
        ),
      );
    }
  }

  List<dynamic> filterContent(List<dynamic> content, String query) {
    if (query.isEmpty) return content;
    String lowerQuery = query.toLowerCase();
    return content.where((item) {
      if (item is Map<String, dynamic>) {
        final name = item['name']?.toString().toLowerCase();
        final title = item['title']?.toString().toLowerCase();
        bool nameMatch = name?.contains(lowerQuery) ?? false;
        bool titleMatch = title?.contains(lowerQuery) ?? false;
        return nameMatch || titleMatch;
      }
      return false;
    }).toList();
  }

  void _prefetchHeroImages(List<dynamic> items, {int limit = 24}) {
    final urls = items
        .map((e) =>
            e is Map ? (e['image_path'] ?? e['image'])?.toString() : null)
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
    final theme = themeProvider.currentTheme;

    // --- Get providers ---
    final authProvider = Provider.of<AuthProvider>(context);
    // --- LISTEN to the ContentCacheProvider for updates ---
    final contentCache = Provider.of<ContentCacheProvider>(context);

    final bool isUserPremium = authProvider.isPremium;

    if (!authProvider.isLoggedIn) {
      return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
              title: const Text("Basirah TV"),
              backgroundColor: isNightMode
                  ? const Color(0xFF1E1E1E)
                  : const Color(0xFF009B77)),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 80, color: Colors.grey[600]),
                const SizedBox(height: 20),
                const Text("Welcome to Basirah TV",
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(
                      "Please log in or sign up to explore our content.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                ),
              ],
            ),
          ));
    }

    // --- Get data from the provider ---
    final filteredSurahs = filterContent(contentCache.surahs, searchQuery);
    final filteredStories = filterContent(contentCache.stories, searchQuery);
    final filteredCourses = filterContent(contentCache.courses, searchQuery);
    final filteredDeeperLooks =
        filterContent(contentCache.deeperLooks, searchQuery);
    final filteredCommentaries =
        filterContent(contentCache.commentaries, searchQuery);

    // Warm image cache once using top items from all sections to avoid reload flicker on scroll.
    if (!_heroImagesPrefetched &&
        (filteredCourses.isNotEmpty ||
            filteredSurahs.isNotEmpty ||
            filteredStories.isNotEmpty ||
            filteredDeeperLooks.isNotEmpty ||
            filteredCommentaries.isNotEmpty)) {
      _heroImagesPrefetched = true;
      _prefetchHeroImages([
        ...filteredCourses,
        ...filteredSurahs,
        ...filteredStories,
        ...filteredDeeperLooks,
        ...filteredCommentaries,
      ]);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () => _fetchAllData(forceRefresh: true),
        color: const Color(0xFF009B77),
        backgroundColor: theme.cardColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isNightMode
                      ? [
                          const Color(0xFF1E1E1E),
                          const Color(0xFF009B77).withOpacity(0.8),
                        ]
                      : [
                          const Color(0xFF009B77),
                          const Color(0xFF00796B),
                        ],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 20,
                  bottom: 60,
                  left: 24,
                  right: 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Basirah TV',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 32.0,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              )
                            ])),
                    const SizedBox(height: 8.0),
                    Text('Explore Quranic teachings, stories, and courses.',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16.0)),
                    const SizedBox(height: 20.0),
                    Container(
                      decoration: BoxDecoration(
                        color: isNightMode
                            ? Colors.black.withOpacity(0.3)
                            : Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          )
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(
                            color: isNightMode ? Colors.white : Colors.black87),
                        onChanged: (value) =>
                            setState(() => searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'Search Surah, Story, Course...',
                          hintStyle: TextStyle(
                              color: isNightMode
                                  ? Colors.white54
                                  : Colors.grey[600]),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.search,
                              color: isNightMode
                                  ? Colors.white54
                                  : Colors.grey[600]),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear,
                                      color: isNightMode
                                          ? Colors.white54
                                          : Colors.grey[600]),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 14.0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8.0),
            _buildSection(context,
                title: 'Quranic Courses',
                description:
                    'Enroll in comprehensive courses to deepen knowledge.',
                content: filteredCourses,
                isLoading: contentCache.isLoading('courses'),
                isNightMode: isNightMode,
                contentType: 'course',
                isUserPremium: isUserPremium),
            const SizedBox(height: 24.0),
            _buildSection(context,
                title: 'Objectives of Surah',
                description:
                    'Explore the objectives and lessons from each Surah.',
                content: filteredSurahs,
                isLoading: contentCache.isLoading('surahs'),
                isNightMode: isNightMode,
                contentType: 'surah',
                isUserPremium: isUserPremium),
            const SizedBox(height: 24.0),
            _buildSection(context,
                title: 'Beyond Stories',
                description: 'Discover inspiring stories from Islamic history.',
                content: filteredStories,
                isLoading: contentCache.isLoading('stories'),
                isNightMode: isNightMode,
                contentType: 'story',
                isUserPremium: isUserPremium),
            const SizedBox(height: 24.0),
            _buildSection(context,
                title: 'Commentary',
                description: 'Gain insights through expert commentary.',
                content: filteredCommentaries,
                isLoading: contentCache.isLoading('commentaries'),
                isNightMode: isNightMode,
                contentType: 'commentary',
                isUserPremium: isUserPremium),
            const SizedBox(height: 24.0),
            _buildSection(context,
                title: 'Deeper Look',
                description:
                    'Explore topics with in-depth analysis and perspectives.',
                content: filteredDeeperLooks,
                isLoading: contentCache.isLoading('deeperLooks'),
                isNightMode: isNightMode,
                contentType: 'deeperLook',
                isUserPremium: isUserPremium),
            const SizedBox(height: 40.0),
          ],
        ),
      ),
    );
  }

  // No changes needed for _buildSection, _buildContentCard, or _navigateToDetail
  // ... (paste your existing _buildSection, _buildContentCard, and _navigateToDetail methods here) ...
  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String description,
    required List<dynamic> content,
    required bool isLoading,
    required bool isNightMode,
    required String contentType,
    required bool isUserPremium,
  }) {
    final itemsToShow = content.take(4).toList();
    Widget? seeAllButton;
    if (content.length > 4 && searchQuery.isEmpty) {
      seeAllButton = TextButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Navigating to $title page...")));
        },
        child: Text('See All',
            style: TextStyle(
                color: isNightMode
                    ? Colors.tealAccent[100]
                    : const Color(0xFF009B77),
                fontSize: 14.0,
                fontWeight: FontWeight.w600)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: isNightMode
                            ? Colors.white
                            : const Color(0xFF00796B),
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold)),
              ),
              if (seeAllButton != null) seeAllButton,
            ],
          ),
          const SizedBox(height: 8.0),
          Text(description,
              style: TextStyle(
                  color: isNightMode ? Colors.white70 : Colors.black54,
                  fontSize: 14.0)),
          const SizedBox(height: 16.0),
          isLoading
              ? const Center(
                  child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: CircularProgressIndicator(color: Color(0xFF009B77)),
                ))
              : itemsToShow.isEmpty
                  ? Center(
                      child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Text(
                        searchQuery.isEmpty
                            ? 'No $title available yet.'
                            : 'No results found for "$searchQuery"',
                        style: TextStyle(
                            color: isNightMode
                                ? Colors.white54
                                : Colors.grey[600]),
                      ),
                    ))
                  : SizedBox(
                      height: 240,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: itemsToShow.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final item = itemsToShow[index];
                          // --- CHANGE #4: Pass isUserPremium to the card builder ---
                          return GestureDetector(
                            onTap: () => _navigateToDetail(contentType, item),
                            child: _buildContentCard(
                                item: item,
                                isNightMode: isNightMode,
                                isUserPremium: isUserPremium),
                          );
                        },
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildContentCard(
      {required Map<String, dynamic> item,
      required bool isNightMode,
      required bool isUserPremium}) {
    String title = item['name'] ?? item['title'] ?? 'Unnamed Content';
    String? imageUrl = item['image_path'] ?? item['image'];

    final bool isContentPremium =
        item['is_premium'] == true || item['is_premium'] == 1;
    final bool showPremiumBadge = isContentPremium && !isUserPremium;

    return Container(
      width: 180,
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: isNightMode ? const Color(0xFF2D2D2D) : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        elevation: 4,
        shadowColor: isNightMode
            ? Colors.black.withOpacity(0.4)
            : Colors.grey.withOpacity(0.3),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16.0)),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl ?? '',
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 140,
                      color: isNightMode ? Colors.grey[800] : Colors.grey[200],
                      child: const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF009B77))),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: isNightMode ? Colors.grey[800] : Colors.grey[200],
                      height: 140,
                      child: Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: isNightMode
                                  ? Colors.grey[500]
                                  : Colors.grey[600],
                              size: 40)),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isNightMode ? Colors.white : Colors.black87,
                        fontSize: 15.0,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            if (showPremiumBadge)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.amber[700]!.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.2), blurRadius: 4)
                      ]),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Premium',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(String contentType, Map<String, dynamic> itemData) {
    if (!mounted) return;
    Widget? detailPage;

    try {
      switch (contentType) {
        case 'course':
          detailPage = CoursePage.CourseDetailPage(course: itemData);
          break;
        case 'surah':
          detailPage = SurahDetailPage(surah: itemData);
          break;
        case 'story':
          detailPage = StoryPage.StoryDetailPage(story: itemData);
          break;
        case 'commentary':
          detailPage = CommentaryDetailPage(commentary: itemData);
          break;
        case 'deeperLook':
          detailPage = DeeperLookDetailPage(deeperLook: itemData);
          break;
        default:
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Cannot open details for this item type.')));
      }

      if (detailPage != null) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                detailPage!,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 200),
          ),
        );
      }
    } catch (e, s) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error opening details.')));
    }
  }
}
