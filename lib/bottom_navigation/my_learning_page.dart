import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

// Import Detail Pages
import '../course/course_detail_page.dart';
import '../surah/surah_detail_page.dart';
import '../story/story_detail_page.dart';
import '../deeper_look/deeper_look_detail_page.dart';
import '../Commentary/commentary_detail_page.dart';

// Import Theme Provider
import '../theme_provider.dart';

// Import Notification Service
import '../services/notification_service.dart';

class MyLearningPage extends StatefulWidget {
  final NotificationService? notificationService;

  const MyLearningPage({super.key, this.notificationService});

  @override
  _MyLearningPageState createState() => _MyLearningPageState();

  void refreshData() {
    print("MyLearningPage widget's refreshData called.");
  }
}

class _MyLearningPageState extends State<MyLearningPage> {
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  bool _isLoading = true;
  bool _isError = false;
  String? _errorMessage;
  List<dynamic> _inProgressContent = [];
  List<dynamic> _completedContent = [];
  String? _phoneNumber;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  bool _prefetchedInProgress = false;
  bool _prefetchedCompleted = false;
  final DefaultCacheManager _cacheManager = DefaultCacheManager();

  @override
  void initState() {
    super.initState();
    _logger.i('MyLearningPage initialized');
    _fetchLearningData();
  }

  /// Retrieves the auth token from SharedPreferences.
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    // <<< FIX: Use the correct key 'token' to match what AuthProvider saves.
    return prefs.getString('token');
  }

  Future<String?> _getPhoneNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phoneNumber = prefs.getString('userPhoneNumber');
      _logger.d('Retrieved phone number: $phoneNumber');
      return phoneNumber;
    } catch (e, stackTrace) {
      _logger.e('Error getting phone number', e, stackTrace);
      return null;
    }
  }

  Future<void> _fetchLearningData() async {
    if (!mounted) {
      _logger.w('_fetchLearningData called when widget is not mounted');
      return;
    }
    _logger.i('Starting to fetch learning data');
    setState(() {
      _isLoading = true;
      _isError = false;
      _errorMessage = null;
    });

    try {
      _phoneNumber = await _getPhoneNumber();
      final token = await _getAuthToken();

      if (token == null || _phoneNumber == null || _phoneNumber!.isEmpty) {
        _logger.w('No token or phone number found - user not logged in');
        if (!mounted) return;
        setState(() {
          _isError = true;
          _errorMessage =
              'Authentication failed. Please log in to view your progress.';
          _isLoading = false;
        });
        return;
      }

      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final Uri uri = Uri.parse(
          'https://admin.basirahtv.com/api/progress/my-learning?phone_number=$_phoneNumber');
      _logger.d('Making API request to: ${uri.toString()}');

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));

      if (!mounted) {
        _logger.w('Widget unmounted during API call');
        return;
      }
      _logger.d('API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          _logger.i('Successfully parsed learning data');
          final inProgress = (data['in_progress'] as List<dynamic>? ?? [])
              .where((item) => _isValidContent(item))
              .toList();
          final completed = (data['completed'] as List<dynamic>? ?? [])
              .where((item) => _isValidContent(item))
              .toList();

          if (mounted) {
            setState(() {
              _inProgressContent = inProgress;
              _completedContent = completed;
              _isLoading = false;
              _isError = false;
            });
          }
          // Warm image caches for both tabs once.
          _prefetchListImages(_inProgressContent, markPrefetched: () {
            _prefetchedInProgress = true;
          }, alreadyPrefetched: _prefetchedInProgress);
          _prefetchListImages(_completedContent, markPrefetched: () {
            _prefetchedCompleted = true;
          }, alreadyPrefetched: _prefetchedCompleted);
          _logger.d(
              'Loaded ${_inProgressContent.length} in-progress items and ${_completedContent.length} completed items');
        } catch (e, stackTrace) {
          _logger.e('Error parsing API response', e, stackTrace);
          if (!mounted) return;
          setState(() {
            _isError = true;
            _errorMessage = 'Error processing data. Please try again.';
            _isLoading = false;
          });
        }
      } else {
        _logger.e('API request failed with status ${response.statusCode}',
            response.body, StackTrace.current);
        if (!mounted) return;
        setState(() {
          _isError = true;
          _errorMessage = _getErrorMessageFromStatusCode(
              response.statusCode, response.body);
          _isLoading = false;
        });
      }
    } on TimeoutException catch (e, stackTrace) {
      _logger.e('API request timed out', e, stackTrace);
      if (!mounted) return;
      setState(() {
        _isError = true;
        _errorMessage = 'Request timed out. Please check your connection.';
        _isLoading = false;
      });
    } on http.ClientException catch (e, stackTrace) {
      _logger.e('Network error occurred', e, stackTrace);
      if (!mounted) return;
      setState(() {
        _isError = true;
        _errorMessage = 'Network error. Please check your internet connection.';
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      _logger.e('Unexpected error fetching learning data', e, stackTrace);
      if (!mounted) return;
      setState(() {
        _isError = true;
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  bool _isValidContent(dynamic content) {
    if (content is! Map<String, dynamic>) return false;
    final contentId = content['content_id'] ?? content['id'];
    if (contentId == null) return false;
    if (contentId is int) return contentId > 0;
    if (contentId is String) {
      final parsedId = int.tryParse(contentId);
      return parsedId != null && parsedId > 0;
    }
    return false;
  }

  void _prefetchListImages(List<dynamic> items,
      {int limit = 20,
      required void Function() markPrefetched,
      bool alreadyPrefetched = false}) {
    if (alreadyPrefetched) return;
    final urls = <String>[];
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final contentType = (item['content_type']?.toString() ?? '').toLowerCase();
      final imagePath = item['image_path']?.toString();
      final imageUrlFromApi = item['image_url']?.toString();
      String? url;
      if (imagePath != null && imagePath.isNotEmpty) {
        url = (contentType == 'course' || !imagePath.startsWith('http'))
            ? "https://admin.basirahtv.com/storage/" + imagePath
            : imagePath;
      } else if (imageUrlFromApi != null && imageUrlFromApi.isNotEmpty) {
        url = imageUrlFromApi;
      }
      if (url != null && url.isNotEmpty) urls.add(url);
      if (urls.length >= limit) break;
    }
    if (urls.isEmpty) return;
    markPrefetched();
    for (final url in urls) {
      unawaited(_cacheManager.getFileFromCache(url).then((cached) async {
        if (cached == null) {
          await _cacheManager.downloadFile(url);
        }
      }).catchError((_) {}));
    }
  }

  String _getErrorMessageFromStatusCode(int statusCode, String responseBody) {
    try {
      final decodedBody = json.decode(responseBody);
      if (decodedBody is Map && decodedBody.containsKey('message')) {
        return decodedBody['message'] as String;
      }
    } catch (_) {/* Ignore */}
    switch (statusCode) {
      case 400:
        return 'Invalid request.';
      case 401:
        return 'Authentication failed. Please log in again.'; // More helpful message
      case 403:
        return 'Permission denied.';
      case 404:
        return 'Not found.';
      case 422:
        return 'Invalid data.';
      case 500:
        return 'Server error.';
      default:
        return 'Failed to load (Error $statusCode).';
    }
  }

  Future<void> _startContentTracking(int contentId, String contentType) async {
    final token = await _getAuthToken();

    if (token == null ||
        _phoneNumber == null ||
        _phoneNumber!.isEmpty ||
        contentId <= 0) {
      _logger.w(
          'Cannot start tracking - missing token, phone number or invalid contentId: $contentId');
      return;
    }

    try {
      _logger.i(
          'Starting content tracking for contentId: $contentId, type: $contentType');

      final response = await http
          .post(
            Uri.parse('https://admin.basirahtv.com/api/progress/start'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'phone_number': _phoneNumber,
              'content_id': contentId,
              'content_type': contentType,
            }),
          )
          .timeout(const Duration(seconds: 10));

      _logger.d('Tracking response status: ${response.statusCode}');
      if (response.statusCode != 200 && response.statusCode != 201) {
        _logger.e('Failed to start tracking for contentId: $contentId',
            response.body, StackTrace.current);
      }
    } catch (e, stackTrace) {
      _logger.e('Error starting content tracking', e, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isNightMode = themeProvider.isDarkMode;
    final primaryColor = Color(0xFF009B77);
    final scaffoldBackgroundColor =
        isNightMode ? Color(0xFF002147) : Colors.grey[50];
    final cardBackgroundColor = isNightMode ? Color(0xFF1E1E1E) : Colors.white;
    final textColor = isNightMode ? Colors.white : Colors.black87;
    final subTextColor = isNightMode ? Colors.white70 : Colors.grey[600];
    final shimmerBaseColor =
        isNightMode ? Colors.grey[800]! : Colors.grey[300]!;
    final shimmerHighlightColor =
        isNightMode ? Colors.grey[700]! : Colors.grey[100]!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('My Learning',
              style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: isNightMode ? Color(0xFF1F1F1F) : primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(icon: Icon(Icons.hourglass_top_rounded), text: 'In Progress'),
              Tab(
                  icon: Icon(Icons.check_circle_outline_rounded),
                  text: 'Completed'),
            ],
          ),
        ),
        body: _buildBody(
          isNightMode,
          cardBackgroundColor,
          textColor,
          subTextColor!,
          primaryColor,
          shimmerBaseColor,
          shimmerHighlightColor,
        ),
      ),
    );
  }

  Widget _buildBody(
    bool isNightMode,
    Color cardBackgroundColor,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
    Color shimmerBaseColor,
    Color shimmerHighlightColor,
  ) {
    if (_isLoading) {
      return _buildShimmerLoading(shimmerBaseColor, shimmerHighlightColor);
    }
    if (_isError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 60),
              SizedBox(height: 20),
              Text('Oops! Something went wrong.',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor),
                  textAlign: TextAlign.center),
              SizedBox(height: 10),
              Text(_errorMessage ?? 'An unknown error occurred.',
                  style: TextStyle(color: subTextColor, fontSize: 15),
                  textAlign: TextAlign.center),
              SizedBox(height: 24),
              ElevatedButton.icon(
                icon: Icon(Icons.refresh_rounded, size: 20),
                label: Text('Try Again', style: TextStyle(fontSize: 15)),
                onPressed: () {
                  _logger.i('User tapped retry button');
                  _fetchLearningData();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
              ),
            ],
          ),
        ),
      );
    }
    return TabBarView(
      children: [
        _buildContentList(
            _inProgressContent,
            "You haven't started any content yet. Explore and learn!",
            isNightMode,
            cardBackgroundColor,
            textColor,
            subTextColor,
            primaryColor),
        _buildContentList(
            _completedContent,
            "You haven't completed any content yet. Keep learning!",
            isNightMode,
            cardBackgroundColor,
            textColor,
            subTextColor,
            primaryColor),
      ],
    );
  }

  Widget _buildShimmerLoading(Color baseColor, Color highlightColor) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child:
              ShimmerCard(baseColor: baseColor, highlightColor: highlightColor),
        );
      },
    );
  }

  Widget _buildContentList(
    List<dynamic> contentList,
    String emptyMessage,
    bool isNightMode,
    Color cardBackgroundColor,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
  ) {
    if (contentList.isEmpty) {
      _logger.d('Showing empty state: $emptyMessage');
      return RefreshIndicator(
        onRefresh: () {
          _logger.i('Refresh on empty list');
          return _fetchLearningData();
        },
        color: primaryColor,
        backgroundColor: cardBackgroundColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.menu_book_rounded,
                            size: 70, color: subTextColor.withOpacity(0.7)),
                        SizedBox(height: 20),
                        Text(emptyMessage,
                            style: TextStyle(
                                fontSize: 17,
                                color: subTextColor,
                                fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center),
                        SizedBox(height: 20),
                        TextButton.icon(
                          icon: Icon(Icons.refresh_rounded, size: 20),
                          label:
                              Text('Refresh', style: TextStyle(fontSize: 15)),
                          onPressed: () {
                            _logger.i('Refresh btn on empty state');
                            _fetchLearningData();
                          },
                          style: TextButton.styleFrom(
                              foregroundColor: primaryColor,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () {
        _logger.i('Refresh on content list');
        return _fetchLearningData();
      },
      color: primaryColor,
      backgroundColor: cardBackgroundColor,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: contentList.length,
        separatorBuilder: (context, index) => SizedBox(height: 12),
        itemBuilder: (context, index) {
          final content = contentList[index];
          if (content is Map<String, dynamic>) {
            return _buildContentCard(content, isNightMode, cardBackgroundColor,
                textColor, subTextColor, primaryColor);
          } else {
            _logger.w(
                'Unexpected data format at index $index: ${content.runtimeType}');
            return SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget _buildContentCard(
    Map<String, dynamic> content,
    bool isNightMode,
    Color cardBackgroundColor,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
  ) {
    final String? name = content['name'] as String?;
    final String contentType = content['content_type'] as String? ?? 'unknown';
    final String status = content['status'] as String? ?? 'not_started';
    int contentId = 0;
    if (content['content_id'] != null) {
      if (content['content_id'] is int) {
        contentId = content['content_id'];
      } else if (content['content_id'] is String) {
        contentId = int.tryParse(content['content_id'] as String) ?? 0;
      }
    } else if (content['id'] != null) {
      if (content['id'] is int) {
        contentId = content['id'];
      } else if (content['id'] is String) {
        contentId = int.tryParse(content['id'] as String) ?? 0;
      }
    }
    _logger.v('Building card for $name (ID: $contentId)');
    String? displayImageUrl;
    final String? imagePath = content['image_path'] as String?;
    final String? imageUrlFromApi = content['image_url'] as String?;
    if (imagePath != null && imagePath.isNotEmpty) {
      displayImageUrl =
          (contentType == 'course' || !imagePath.startsWith('http'))
              ? "https://admin.basirahtv.com/storage/" + imagePath
              : imagePath;
    } else if (imageUrlFromApi != null && imageUrlFromApi.isNotEmpty) {
      displayImageUrl = imageUrlFromApi;
    }
    Map<String, dynamic> originalData = {};
    try {
      final dynamic rawOriginalData = content['original_data'];
      if (rawOriginalData is Map<String, dynamic>) {
        originalData = rawOriginalData;
      } else if (rawOriginalData is String && rawOriginalData.isNotEmpty) {
        originalData = json.decode(rawOriginalData) as Map<String, dynamic>;
      } else {
        originalData =
            _createFallbackData(content, name, contentType, contentId);
      }
    } catch (e) {
      originalData = _createFallbackData(content, name, contentType, contentId);
    }
    if (originalData['id'] == null && contentId > 0)
      originalData['id'] = contentId;
    IconData typeIcon;
    switch (contentType.toLowerCase()) {
      case 'course':
        typeIcon = Icons.school_outlined;
        break;
      case 'surah':
        typeIcon = Icons.menu_book_outlined;
        break;
      case 'story':
        typeIcon = Icons.auto_stories_outlined;
        break;
      case 'deeper_look':
        typeIcon = Icons.search_outlined;
        break;
      case 'commentary':
        typeIcon = Icons.comment_outlined;
        break;
      default:
        typeIcon = Icons.library_books_outlined;
    }
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: cardBackgroundColor,
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          _logger.i('Tap on $name (ID: $contentId)');
          if (contentId > 0) {
            _startContentTracking(contentId, contentType);
            _navigateToDetail(contentType, originalData, context);
          } else {
            _logger.e('Invalid contentId ($contentId)');
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Cannot open invalid content.')));
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isNightMode ? Colors.grey[700] : Colors.grey[200]),
                child: displayImageUrl != null && displayImageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: displayImageUrl,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      cacheManager: _cacheManager,
                      placeholder: (ctx, url) => Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            primaryColor))),
                      errorWidget: (ctx, url, err) {
                      _logger.e('Failed img load: $displayImageUrl', err);
                      return Center(
                        child: Icon(typeIcon,
                          size: 36,
                          color: subTextColor.withOpacity(0.8)));
                      },
                    ),
                      )
                    : Center(
                        child: Icon(typeIcon,
                            size: 36, color: subTextColor.withOpacity(0.8))),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name ?? 'Untitled Content',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                            status == 'completed'
                                ? Icons.check_circle_rounded
                                : Icons.timelapse_rounded,
                            size: 16,
                            color: status == 'completed'
                                ? Colors.green.shade500
                                : primaryColor),
                        SizedBox(width: 5),
                        Text(
                            status == 'completed' ? 'Completed' : 'In Progress',
                            style: TextStyle(
                                color: status == 'completed'
                                    ? Colors.green.shade600
                                    : primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    SizedBox(height: 3),
                    Text(contentType.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                            color: subTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: subTextColor, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _createFallbackData(
    Map<String, dynamic> content,
    String? name,
    String contentType,
    int contentId,
  ) {
    _logger.w('Creating fallback data for $name (ID: $contentId)');
    final fallback = {
      'id': contentId,
      'content_id': contentId,
      'name': name ?? 'Untitled $contentType',
      'content_type': contentType,
    };
    return {...content, ...fallback};
  }

  void _navigateToDetail(
    String contentType,
    Map<String, dynamic> originalData,
    BuildContext currentContext,
  ) async {
    _logger.i('Navigating to $contentType detail');
    Widget? detailPage;
    try {
      if (originalData['id'] == null && originalData['content_id'] != null) {
        originalData['id'] = originalData['content_id'];
      }
      switch (contentType.toLowerCase()) {
        case 'course':
          detailPage = CourseDetailPage(course: originalData);
          break;
        case 'surah':
          detailPage = SurahDetailPage(surah: originalData);
          break;
        case 'story':
          detailPage = StoryDetailPage(story: originalData);
          break;
        case 'deeper_look':
          detailPage = DeeperLookDetailPage(deeperLook: originalData);
          break;
        case 'commentary':
          detailPage = CommentaryDetailPage(commentary: originalData);
          break;
        default:
          _logger.w('Unknown type: $contentType');
          if (currentContext.mounted)
            ScaffoldMessenger.of(currentContext).showSnackBar(SnackBar(
                content: Text('Cannot open details.'),
                behavior: SnackBarBehavior.floating));
          return;
      }
    } catch (e, stackTrace) {
      _logger.e('Error creating detail page', e, stackTrace);
      if (currentContext.mounted)
        ScaffoldMessenger.of(currentContext).showSnackBar(SnackBar(
            content: Text('Error preparing details.'),
            behavior: SnackBarBehavior.floating));
      return;
    }
    if (currentContext.mounted) {
      try {
        await Navigator.push(currentContext,
            MaterialPageRoute(builder: (context) => detailPage!));
        if (mounted) {
          _logger.i('Returned from detail - refreshing');
          _fetchLearningData();
        }
      } catch (e, stackTrace) {
        _logger.e('Error during nav', e, stackTrace);
      }
    }
  }
}

class ShimmerCard extends StatelessWidget {
  final Color baseColor;
  final Color highlightColor;
  const ShimmerCard({
    required this.baseColor,
    required this.highlightColor,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: baseColor, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                  color: highlightColor,
                  borderRadius: BorderRadius.circular(8))),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    width: double.infinity,
                    height: 18,
                    decoration: BoxDecoration(
                        color: highlightColor,
                        borderRadius: BorderRadius.circular(4))),
                SizedBox(height: 8),
                Container(
                    width: 120,
                    height: 14,
                    decoration: BoxDecoration(
                        color: highlightColor,
                        borderRadius: BorderRadius.circular(4))),
                SizedBox(height: 6),
                Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                        color: highlightColor,
                        borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
