import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async' show unawaited;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../services/bookmark_service.dart';
import '../providers/auth_provider.dart';
import '../theme_provider.dart';

import 'course/course_detail_page.dart';
import 'surah/surah_detail_page.dart';
import 'story/story_detail_page.dart';
import 'Commentary/commentary_detail_page.dart';
import 'deeper_look/deeper_look_detail_page.dart';
import '/../media/video_player_page.dart';
import '/../media/audio_player_page.dart';
import '/../media/youtube_player_page.dart';

const String _apiBaseUrl = "https://admin.basirahtv.com";

class BookmarksTab extends StatefulWidget {
  const BookmarksTab({Key? key}) : super(key: key);

  @override
  _BookmarksTabState createState() => _BookmarksTabState();
}

class _BookmarksTabState extends State<BookmarksTab>
  with AutomaticKeepAliveClientMixin<BookmarksTab> {
  // --- STATE MANAGEMENT REFACTORED ---
  final BookmarkService _bookmarkService = BookmarkService();
  List<dynamic> _allBookmarks = []; // This holds the raw API response
  final DefaultCacheManager _cacheManager = DefaultCacheManager();
  bool _prefetchedImages = false;

  // These are now COMPUTED properties that filter the single source of truth
  List<dynamic> get _bookmarkedContent => _allBookmarks
      .where((b) =>
          b['bookmarkable'] != null &&
          b['bookmarkable_type'] is String &&
          !b['bookmarkable_type'].contains('Episode'))
      .toList();

  List<dynamic> get _bookmarkedEpisodes => _allBookmarks
      .where((b) =>
          b['bookmarkable'] != null &&
          b['bookmarkable_type'] is String &&
          b['bookmarkable_type'].contains('Episode'))
      .toList();

  bool _isLoading = true;
  String _error = '';
  int _selectedIndex = 0; // 0 for Content, 1 for Episodes

  @override
  void initState() {
    super.initState();
    // We use addPostFrameCallback to ensure the Provider is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookmarks();
    });
  }

  // --- DATA FETCHING REFACTORED ---
  Future<void> _loadBookmarks() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      if (token == null) {
        throw Exception('User is not authenticated. Please log in.');
      }

      // SINGLE API CALL to get all bookmarks!
      final bookmarks = await _bookmarkService.fetchAllBookmarks(token);

      if (!mounted) return;
      setState(() {
        _allBookmarks = bookmarks;
      });
      _prefetchBookmarkedImages();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to load bookmarks. Please check your connection.";
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- TOGGLE LOGIC REFACTORED ---
  Future<void> _toggleBookmark(dynamic bookmark) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) {
      _showSnackbar('Authentication error.', isError: true);
      return;
    }

    final String bookmarkableType = bookmark['bookmarkable_type'];
    final int bookmarkableId = bookmark['bookmarkable']['id'];

    // Convert the full model path to the simple API type string
    final String apiType = _mapModelToApiType(bookmarkableType);

    if (apiType.isEmpty) {
      _showSnackbar('Cannot bookmark unknown content type.', isError: true);
      return;
    }

    // Optimistically remove the item from the list for a snappy UI
    setState(() {
      _allBookmarks.removeWhere((b) => b['id'] == bookmark['id']);
    });

    try {
      final message = await _bookmarkService.toggleBookmark(
        token: token,
        bookmarkableType: apiType,
        bookmarkableId: bookmarkableId,
      );
      _showSnackbar(message);
      // We don't need to call _loadBookmarks() again due to optimistic removal
    } catch (e) {
      _showSnackbar('Error updating bookmark. Please try again.',
          isError: true);
      // If the API call fails, refresh the list to add the item back
      _loadBookmarks();
    }
  }

  /// Helper to convert full Laravel model path to the short API type string.
  /// --- THIS IS THE CORRECTED FUNCTION ---
  String _mapModelToApiType(String modelPath) {
    // Check for the most specific episode types FIRST
    if (modelPath.endsWith('SurahEpisode')) return 'surah_episode';
    if (modelPath.endsWith('StoryEpisode')) return 'story_episode';
    if (modelPath.endsWith('CommentaryEpisode')) return 'commentary_episode';
    if (modelPath.endsWith('DeeperLookEpisode')) return 'deeper_look_episode';

    // Now, check for the general "parent" types and the generic Episode
    if (modelPath.endsWith('Course')) return 'course';
    if (modelPath.endsWith('Surah')) return 'surah';
    if (modelPath.endsWith('Story')) return 'story';
    if (modelPath.endsWith('Commentary')) return 'commentary';
    if (modelPath.endsWith('DeeperLook')) return 'deeper_look';
    if (modelPath.endsWith('Episode'))
      return 'episode'; // This will now only match the plain course Episode

    return ''; // Return empty for unknown types
  }

  // --- HELPER FUNCTIONS (from your original code) ---
  bool _hasMedia(Map<String, dynamic> episode) {
    return (episode['video_path'] != null &&
            episode['video_path'].isNotEmpty) ||
        (episode['video'] != null && episode['video'].isNotEmpty) ||
        (episode['audio_path'] != null && episode['audio_path'].isNotEmpty) ||
        (episode['audio'] != null && episode['audio'].isNotEmpty) ||
        (episode['youtube_link'] != null && episode['youtube_link'].isNotEmpty);
  }

  String? _getMediaPath(Map<String, dynamic> item, String type) {
    String? path;
    if (type == 'video') {
      path = item['video_path'] ?? item['video'];
    } else if (type == 'audio') {
      path = item['audio_path'] ?? item['audio'];
    }
    return (path != null && path.isNotEmpty) ? path : null;
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    final isNightMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.redAccent.shade700
            : (isNightMode ? Colors.grey[700] : const Color(0xFF009B77)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- UI BUILDING SECTION ---
  @override
  Widget build(BuildContext context) {
    super.build(context); // Ensure keep-alive works
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isNightMode = themeProvider.isDarkMode;
    final Color primaryColor = const Color(0xFF009B77);

    final Color scaffoldBgColor =
        isNightMode ? const Color(0xFF002147) : Colors.grey[50]!;
    final Color refreshIndicatorSpinnerColor = primaryColor;
    final Color refreshIndicatorBgColor =
        isNightMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      body: RefreshIndicator(
        onRefresh: _loadBookmarks,
        color: refreshIndicatorSpinnerColor,
        backgroundColor: refreshIndicatorBgColor,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
                child: _buildSegmentedControl(isNightMode, primaryColor)),
            _isLoading
                ? _buildLoadingState(isNightMode)
                : _error.isNotEmpty
                    ? _buildErrorState(isNightMode, _error)
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        sliver: _selectedIndex == 0
                            ? _buildContentList(isNightMode, primaryColor)
                            : _buildEpisodesList(isNightMode, primaryColor),
                      ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  Widget _buildContentList(bool isNightMode, Color primaryColor) {
    final List<dynamic> allContent = _bookmarkedContent;

    if (allContent.isEmpty) {
      return _buildEmptyListState(isNightMode, isContent: true);
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final bookmarkItem = allContent[index];
          return _buildContentCard(bookmarkItem, isNightMode, primaryColor);
        },
        childCount: allContent.length,
      ),
    );
  }

  Widget _buildContentCard(
      Map<String, dynamic> bookmarkItem, bool isNightMode, Color primaryColor) {
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(bookmarkItem['bookmarkable'] ?? {});
    final String type = _mapModelToApiType(bookmarkItem['bookmarkable_type']);
    final int? itemId = int.tryParse(data['id']?.toString() ?? '');

    String title = 'Untitled';
    IconData iconData = Icons.bookmark_outline;

    switch (type) {
      case 'course':
        title = data['name'] ?? 'Course';
        iconData = Icons.school_outlined;
        break;
      case 'surah':
        title = data['name'] ?? 'Surah';
        iconData = Icons.book_outlined;
        break;
      case 'story':
        title = data['name'] ?? 'Story';
        iconData = Icons.auto_stories_outlined;
        break;
      case 'commentary':
        title = data['title'] ?? 'Commentary';
        iconData = Icons.comment_bank_outlined;
        break;
      case 'deeper_look':
        title = data['name'] ?? 'Deeper Look';
        iconData = Icons.video_library_outlined;
        break;
    }

    final String? imagePath = data['image_path'] ?? data['image'];
    final bool hasImage = imagePath != null && imagePath.isNotEmpty;
    final String? fullImageUrl =
        hasImage ? '$_apiBaseUrl/storage/$imagePath' : null;

    final Color cardBgColor =
        isNightMode ? const Color(0xFF1E1E1E) : Colors.white;
    final Color titleColor = isNightMode ? Colors.white : Colors.black;
    final Color subtitleColor =
        isNightMode ? Colors.white70 : Colors.grey[600]!;
    final Color removeIconColor = Colors.redAccent.shade200;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardBgColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (itemId == null) {
            _showSnackbar("Cannot open item: Invalid ID.", isError: true);
            return;
          }
          Widget detailPage;
          switch (type) {
            case 'course':
              detailPage = CourseDetailPage(course: data);
              break;
            case 'surah':
              detailPage = SurahDetailPage(surah: data);
              break;
            case 'story':
              detailPage = StoryDetailPage(story: data);
              break;
            case 'commentary':
              detailPage = CommentaryDetailPage(commentary: data);
              break;
            case 'deeper_look':
              detailPage = DeeperLookDetailPage(deeperLook: data);
              break;
            default:
              return;
          }
          Navigator.push(
                  context, MaterialPageRoute(builder: (context) => detailPage))
              .then((_) => _loadBookmarks());
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              _buildLeadingImage(
                  fullImageUrl, iconData, isNightMode, primaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: titleColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                          type
                              .replaceAll('_', ' ')
                              .split(' ')
                              .map((w) => w[0].toUpperCase() + w.substring(1))
                              .join(' '),
                          style: TextStyle(color: subtitleColor, fontSize: 13)),
                    ]),
              ),
              if (itemId != null)
                IconButton(
                  icon: Icon(Icons.bookmark_remove_outlined,
                      color: removeIconColor, size: 22),
                  tooltip: "Remove Bookmark",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _toggleBookmark(bookmarkItem),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodesList(bool isNightMode, Color primaryColor) {
    final List<dynamic> allEpisodes = _bookmarkedEpisodes;

    if (allEpisodes.isEmpty) {
      return _buildEmptyListState(isNightMode, isContent: false);
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final bookmarkItem = allEpisodes[index];
          return _buildEpisodeCard(bookmarkItem, isNightMode, primaryColor);
        },
        childCount: allEpisodes.length,
      ),
    );
  }

  Widget _buildEpisodeCard(
      Map<String, dynamic> bookmarkItem, bool isNightMode, Color primaryColor) {
    final Map<String, dynamic> episode =
        Map<String, dynamic>.from(bookmarkItem['bookmarkable'] ?? {});
    final String bookmarkableType = bookmarkItem['bookmarkable_type'];

    final String title =
        episode['title'] ?? episode['name'] ?? 'Untitled Episode';
    final int? episodeId = int.tryParse(episode['id']?.toString() ?? '');
    final String? description = episode['description']?.toString();

    String parentTypeLabel = 'Episode';
    int? parentId;
    String contentTypeForPlayer = 'episode';
    String sourceType = _mapModelToApiType(bookmarkableType);

    switch (sourceType) {
      case 'episode': // Default 'Episode' model from 'courses'
        parentTypeLabel = 'Course';
        parentId = int.tryParse(episode['course_id']?.toString() ?? '');
        contentTypeForPlayer = 'course';
        break;
      case 'surah_episode':
        parentTypeLabel = 'Surah';
        parentId = int.tryParse(episode['surah_id']?.toString() ?? '');
        contentTypeForPlayer = 'surah';
        break;
      case 'story_episode':
        parentTypeLabel = 'Story';
        parentId = int.tryParse(episode['story_id']?.toString() ?? '');
        contentTypeForPlayer = 'story';
        break;
      case 'commentary_episode':
        parentTypeLabel = 'Commentary';
        parentId = int.tryParse(episode['commentary_id']?.toString() ?? '');
        contentTypeForPlayer = 'commentary';
        break;
      case 'deeper_look_episode':
        parentTypeLabel = 'Deeper Look';
        parentId = int.tryParse(episode['deeper_look_id']?.toString() ?? '');
        contentTypeForPlayer = 'deeper_look';
        break;
    }

    final bool hasVideo = _getMediaPath(episode, 'video') != null;
    final bool hasAudio = _getMediaPath(episode, 'audio') != null;
    final bool hasYoutube =
        episode['youtube_link'] != null && episode['youtube_link'].isNotEmpty;
    final bool hasAnyMedia = hasVideo || hasAudio || hasYoutube;

    final Color cardBgColor =
        isNightMode ? const Color(0xFF1E1E1E) : Colors.white;
    final Color iconContainerBgColor = primaryColor.withOpacity(0.15);
    final Color iconColor = primaryColor;
    final Color titleColor = isNightMode ? Colors.white : Colors.black;
    final Color subtitleColor =
        isNightMode ? Colors.white70 : Colors.grey[600]!;
    final Color descriptionColor =
        isNightMode ? Colors.white60 : Colors.grey[700]!;
    final Color removeIconColor = Colors.redAccent.shade200;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardBgColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: hasAnyMedia
            ? () => _playFirstAvailableMedia(
                episode, parentId, contentTypeForPlayer)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: iconContainerBgColor,
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(_getSourceTypeIcon(sourceType),
                        color: iconColor, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: titleColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis)),
                if (episodeId != null)
                  IconButton(
                      icon: Icon(Icons.bookmark_remove_outlined,
                          color: removeIconColor, size: 22),
                      tooltip: "Remove Bookmark",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _toggleBookmark(bookmarkItem)),
              ]),
              const SizedBox(height: 8),
              Text('$parentTypeLabel Episode',
                  style: TextStyle(fontSize: 13, color: subtitleColor)),
              if (description != null && description.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(description,
                    style: TextStyle(fontSize: 13, color: descriptionColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 12),
              if (hasAnyMedia)
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (hasVideo)
                    _buildMediaTag(
                        icon: Icons.videocam_outlined,
                        label: 'Video',
                        isNightMode: isNightMode,
                        onTap: () => _playVideo(
                            episode, parentId, contentTypeForPlayer)),
                  if (hasYoutube)
                    _buildMediaTag(
                        icon: Icons.smart_display_outlined,
                        label: 'Video',
                        isNightMode: isNightMode,
                        onTap: () => _playYoutube(
                            episode, parentId, contentTypeForPlayer)),
                  if (hasAudio)
                    _buildMediaTag(
                        icon: Icons.audiotrack_outlined,
                        label: 'Audio',
                        isNightMode: isNightMode,
                        onTap: () => _playAudio(
                            episode, parentId, contentTypeForPlayer)),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  // --- ALL REMAINING UI HELPER WIDGETS ---
  // (These are unchanged from your original code)

  Widget _buildSegmentedControl(bool isNightMode, Color primaryColor) {
    final Color selectedBgColor = primaryColor;
    final Color unselectedBgColor =
        isNightMode ? const Color(0xFF2C2C34) : Colors.grey[200]!;
    final Color selectedTextColor = Colors.white;
    final Color unselectedTextColor =
        isNightMode ? Colors.white70 : Colors.black54;
    final Color unselectedBorderColor =
        isNightMode ? Colors.grey[700]! : Colors.grey[300]!;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _buildSegmentButton(
              0,
              'Content',
              isNightMode,
              selectedBgColor,
              unselectedBgColor,
              selectedTextColor,
              unselectedTextColor,
              unselectedBorderColor),
          const SizedBox(width: 8),
          _buildSegmentButton(
              1,
              'Episodes',
              isNightMode,
              selectedBgColor,
              unselectedBgColor,
              selectedTextColor,
              unselectedTextColor,
              unselectedBorderColor),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(
      int index,
      String text,
      bool isNightMode,
      Color selectedBgColor,
      Color unselectedBgColor,
      Color selectedTextColor,
      Color unselectedTextColor,
      Color unselectedBorderColor) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: isSelected ? selectedBgColor : unselectedBgColor,
              borderRadius: BorderRadius.horizontal(
                left: index == 0 ? const Radius.circular(8) : Radius.zero,
                right: index == 1 ? const Radius.circular(8) : Radius.zero,
              ),
              border: isSelected
                  ? null
                  : Border.all(color: unselectedBorderColor, width: 0.5)),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isSelected ? selectedTextColor : unselectedTextColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaTag(
      {required IconData icon,
      required String label,
      required bool isNightMode,
      required VoidCallback onTap}) {
    final Color tagColor = const Color(0xFF009B77);
    final Color tagBgColor =
        isNightMode ? tagColor.withOpacity(0.2) : tagColor.withOpacity(0.1);
    final Color tagBorderColor =
        isNightMode ? tagColor.withOpacity(0.4) : tagColor.withOpacity(0.3);

    return Material(
        color: Colors.transparent,
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: tagColor.withOpacity(0.3),
            highlightColor: tagColor.withOpacity(0.2),
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: tagBgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tagBorderColor, width: 0.5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 14, color: tagColor),
                  const SizedBox(width: 5),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: tagColor,
                          fontWeight: FontWeight.w600)),
                ]))));
  }

  IconData _getSourceTypeIcon(String type) {
    switch (type) {
      case 'course':
      case 'episode':
        return Icons.school_outlined;
      case 'surah':
      case 'surah_episode':
        return Icons.book_outlined;
      case 'story':
      case 'story_episode':
        return Icons.auto_stories_outlined;
      case 'commentary':
      case 'commentary_episode':
        return Icons.comment_bank_outlined;
      case 'deeper_look':
      case 'deeper_look_episode':
        return Icons.video_library_outlined;
      default:
        return Icons.play_circle_outline;
    }
  }

  Widget _buildLeadingImage(String? fullImageUrl, IconData iconData,
      bool isNightMode, Color primaryColor) {
    final Color placeholderBg =
        isNightMode ? Colors.grey[800]! : Colors.grey[200]!;
    final Color placeholderIconColor =
        isNightMode ? Colors.grey[500]! : Colors.grey[400]!;
    final Color loadingSpinnerColor = primaryColor;
    const double imageSize = 60.0;

    if (fullImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: CachedNetworkImage(
          imageUrl: fullImageUrl,
          cacheManager: _cacheManager,
          width: imageSize,
          height: imageSize,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 0),
          fadeOutDuration: const Duration(milliseconds: 0),
          useOldImageOnUrlChange: true,
          placeholder: (context, url) => Container(
            width: imageSize,
            height: imageSize,
            color: placeholderBg,
          ),
          errorWidget: (context, url, error) => Container(
              width: imageSize,
              height: imageSize,
              decoration: BoxDecoration(
                  color: placeholderBg,
                  borderRadius: BorderRadius.circular(8.0)),
              child: Icon(iconData, color: placeholderIconColor, size: 30)),
        ),
      );
    } else {
      return Container(
          width: imageSize,
          height: imageSize,
          decoration: BoxDecoration(
              color: placeholderBg, borderRadius: BorderRadius.circular(8.0)),
          child: Icon(iconData, color: placeholderIconColor, size: 30));
    }
  }

  void _prefetchBookmarkedImages({int limit = 24}) {
    if (_prefetchedImages) return;
    final urls = <String>[];
    for (final b in _bookmarkedContent) {
      final data = Map<String, dynamic>.from(b['bookmarkable'] ?? {});
      final imagePath = (data['image_path'] ?? data['image'])?.toString();
      if (imagePath != null && imagePath.isNotEmpty) {
        urls.add('$_apiBaseUrl/storage/$imagePath');
        if (urls.length >= limit) break;
      }
    }
    if (urls.isEmpty) return;
    _prefetchedImages = true;
    for (final url in urls) {
      unawaited(_cacheManager.getFileFromCache(url).then((cached) async {
        if (cached == null) {
          await _cacheManager.downloadFile(url);
        }
      }).catchError((_) {}));
    }
  }

  Widget _buildEmptyListState(bool isNightMode, {required bool isContent}) {
    final Color iconColor = isNightMode ? Colors.grey[600]! : Colors.grey[400]!;
    final Color titleColor = isNightMode ? Colors.white : Colors.black;
    final Color textColor = isNightMode ? Colors.white70 : Colors.grey[600]!;

    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  isContent
                      ? Icons.bookmark_border_rounded
                      : Icons.playlist_play_outlined,
                  size: 70,
                  color: iconColor),
              const SizedBox(height: 20),
              Text(
                  isContent
                      ? 'No Bookmarked Content'
                      : 'No Bookmarked Episodes',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: titleColor)),
              const SizedBox(height: 8),
              Text(
                  isContent
                      ? 'Bookmark courses, commentaries, etc.'
                      : 'Bookmark individual episodes to find them here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isNightMode, String errorMsg) {
    final Color iconColor = Colors.redAccent;
    final Color titleColor = isNightMode ? Colors.white : Colors.black87;
    final Color messageColor =
        isNightMode ? Colors.grey[400]! : Colors.grey[600]!;
    final Color buttonBgColor = const Color(0xFF009B77);
    final Color buttonFgColor = Colors.white;

    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 60, color: iconColor),
              const SizedBox(height: 16),
              Text('Failed to Load Bookmarks',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: titleColor)),
              const SizedBox(height: 8),
              Text(errorMsg,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: messageColor)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  onPressed: _loadBookmarks,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: buttonBgColor,
                      foregroundColor: buttonFgColor))
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isNightMode) {
    final Color spinnerColor = const Color(0xFF009B77);
    final Color textColor = isNightMode ? Colors.white70 : Colors.grey[600]!;

    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(spinnerColor)),
            const SizedBox(height: 16),
            Text('Loading your bookmarks...',
                style: TextStyle(color: textColor, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  // --- Media Playback Navigation ---

  void _playFirstAvailableMedia(
      Map<String, dynamic> episode, int? parentId, String contentType) {
    final String? videoPath = _getMediaPath(episode, 'video');
    final String? audioPath = _getMediaPath(episode, 'audio');
    final String? youtubeUrl = episode['youtube_link'];

    if (videoPath != null) {
      _playVideo(episode, parentId, contentType);
    } else if (youtubeUrl != null && youtubeUrl.isNotEmpty) {
      _playYoutube(episode, parentId, contentType);
    } else if (audioPath != null) {
      _playAudio(episode, parentId, contentType);
    } else {
      _showSnackbar("No playable media found for this episode.", isError: true);
    }
  }

  void _playVideo(
      Map<String, dynamic> episode, int? parentId, String contentType) {
    final String? videoPath = _getMediaPath(episode, 'video');
    final int? episodeId = int.tryParse(episode['id']?.toString() ?? '');
    final String title = episode['title'] ?? episode['name'] ?? 'Video';

    if (videoPath == null || episodeId == null || parentId == null) {
      _showSnackbar("Cannot play video: Missing required data.", isError: true);
      return;
    }
    final String fullVideoUrl = '$_apiBaseUrl/storage/$videoPath';

    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => VideoPlayerPage(
                  videoUrl: fullVideoUrl,
                  episodeTitle: title,
                  episodeId: episodeId,
                  contentId: parentId,
                  contentType: contentType,
                  episodes: const [],
                  otherEpisodes: const [],
                )));
  }

  void _playYoutube(
      Map<String, dynamic> episode, int? parentId, String contentType) {
    final String? youtubeUrl = episode['youtube_link'];
    final int? episodeId = int.tryParse(episode['id']?.toString() ?? '');
    final String title = episode['title'] ?? episode['name'] ?? 'YouTube Video';

    if (youtubeUrl == null ||
        youtubeUrl.isEmpty ||
        episodeId == null ||
        parentId == null) {
      _showSnackbar("Cannot play YouTube video: Invalid link or missing data.",
          isError: true);
      return;
    }

    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => YouTubePlayerPage(
                  initialYoutubeUrl: youtubeUrl,
                  initialEpisodeTitle: title,
                  initialEpisodeId: episodeId,
                  contentId: parentId,
                  contentType: contentType,
                  otherEpisodes: const [],
                  youtubeUrl: youtubeUrl,
                  episodeTitle: title,
                  episodeId: episodeId,
                )));
  }

  void _playAudio(
      Map<String, dynamic> episode, int? parentId, String contentType) {
    final String? audioPath = _getMediaPath(episode, 'audio');
    final int? episodeId = int.tryParse(episode['id']?.toString() ?? '');
    final String title = episode['title'] ?? episode['name'] ?? 'Audio';

    if (audioPath == null || episodeId == null || parentId == null) {
      _showSnackbar("Cannot play audio: Missing required data.", isError: true);
      return;
    }
    final String fullAudioUrl = '$_apiBaseUrl/storage/$audioPath';

    String parentTitle = contentType
        .split('_')
        .map((e) => e[0].toUpperCase() + e.substring(1))
        .join(' ');
    String? parentImageUrl;

    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AudioPlayerPage(
                  audioUrl: fullAudioUrl,
                  episodeTitle: title,
                  storyTitle: parentTitle,
                  episodeId: episodeId,
                  contentId: parentId,
                  contentType: contentType,
                  currentEpisodeId: episodeId,
                  imageUrl: parentImageUrl,
                  episodes: const [],
                )));
  }
}
