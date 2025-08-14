import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import '../../media/audio_player_page.dart';
import '../../media/video_player_page.dart';
import '../../media/youtube_player_page.dart';
import '../../models/content_type.dart';
// --- NEW IMPORT ---
import '../../models/playlist/playlist.dart'; // Import the new strongly-typed model
import '../../providers/auth_provider.dart';
import '../../services/bookmark_service.dart';
import '../../services/content_detail_services/api_service.dart';
import '../../services/content_detail_services/content_service.dart';
import '../../services/content_detail_services/playlist_service.dart';
import '../../services/content_detail_services/ui_service.dart';
import '../../services/content_detail_services/user_service.dart';
import '../../theme_provider.dart';
import '../topbar/subscription_page.dart';

class CommentaryDetailPage extends StatefulWidget {
  final Map<String, dynamic> commentary;
  const CommentaryDetailPage({required this.commentary, Key? key})
      : super(key: key);
  @override
  _CommentaryDetailPageState createState() => _CommentaryDetailPageState();
}

class _CommentaryDetailPageState extends State<CommentaryDetailPage> {
  // --- STATE AND SERVICE (No changes needed here) ---
  final BookmarkService _bookmarkService = BookmarkService();
  bool _isUserPremium = false;
  List<dynamic>? _episodes;
  Map<int, bool> _episodeBookmarks = {};
  bool _isLoadingEpisodes = true;
  String? _errorLoadingEpisodes;

  late final UserService _userService;
  late final ContentService _contentService;
  late final PlaylistService _playlistService;
  late final UIService _uiService;
  final _logger = Logger();

  ContentType get _contentType => ContentType.commentary;
  int get _parentId => int.parse(widget.commentary['id'].toString());
  Map<String, dynamic> get _content => widget.commentary;

  AuthProvider get _authProvider =>
      Provider.of<AuthProvider>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _logger.i(
        "CommentaryDetailPage initialized for ID: $_parentId, Title: '${_getTitle(widget.commentary)}'");
    // Use a single ApiService instance for consistency
    final apiService = ApiService();
    _userService = UserService();
    _contentService = ContentService(apiService);
    _playlistService = PlaylistService(apiService);
    _uiService = UIService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAllInitialData();
    });
  }

  // --- CORE LOGIC (No changes needed for fetching episodes/bookmarks) ---
  Future<void> _fetchAllInitialData() async {
    if (!mounted) return;
    _logger.i("Fetching initial data for Commentary ID: $_parentId");
    setState(() {
      _isLoadingEpisodes = true;
      _errorLoadingEpisodes = null;
    });

    final token = _authProvider.token;
    if (token == null) {
      _logger.w("Cannot fetch details: User is not logged in (token is null).");
      if (mounted) {
        setState(() {
          _errorLoadingEpisodes = "Please log in to view this content.";
          _isLoadingEpisodes = false;
        });
      }
      return;
    }

    try {
      _logger
          .d("Fetching premium status, episodes, and bookmarks in parallel.");
      final premiumFuture = _userService.isUserPremium();
      final episodesFuture =
          _contentService.fetchEpisodes(_contentType, _parentId, token);
      final bookmarksFuture = _bookmarkService.fetchAllBookmarks(token);

      _isUserPremium = await premiumFuture;
      _episodes = await episodesFuture;
      final allBookmarks = await bookmarksFuture;
      if (!mounted) return;

      final bookmarkedEpisodeIds = allBookmarks
          .where((b) => b['bookmarkable_type'].endsWith('CommentaryEpisode'))
          .map((b) => int.parse(b['bookmarkable_id'].toString()))
          .toSet();

      if (mounted && _episodes != null) {
        setState(() {
          _episodeBookmarks = {
            for (var ep in _episodes!)
              int.parse(ep['id'].toString()):
                  bookmarkedEpisodeIds.contains(int.parse(ep['id'].toString()))
          };
        });
      }

      _logger.i(
          "Successfully fetched initial data. Premium: $_isUserPremium, Episodes: ${_episodes?.length}, Bookmarks: ${_episodeBookmarks.length}");
      _contentService.trackContentStart(_contentType, _parentId, token);
      if (mounted) setState(() => _isLoadingEpisodes = false);
    } catch (e, stackTrace) {
      _logger.e("Error in _fetchAllInitialData for Commentary ID: $_parentId",
          e, stackTrace);
      if (!mounted) return;
      setState(() {
        _errorLoadingEpisodes = "Failed to load content. Pull down to retry.";
        _isLoadingEpisodes = false;
      });
    }
  }

  Future<void> _toggleBookmark(int episodeId) async {
    _logger.i("Toggling bookmark for commentary episode ID: $episodeId");
    final token = _authProvider.token;
    if (token == null) {
      _logger.w("Cannot toggle bookmark: User is not logged in.");
      _uiService.showErrorSnackbar('Please log in to manage bookmarks.');
      return;
    }

    final bool isCurrentlyBookmarked = _episodeBookmarks[episodeId] ?? false;
    setState(() => _episodeBookmarks[episodeId] = !isCurrentlyBookmarked);

    try {
      final message = await _bookmarkService.toggleBookmark(
          token: token,
          bookmarkableType: 'commentary_episode',
          bookmarkableId: episodeId);
      _logger.i(
          "Bookmark toggled successfully for commentary episode ID: $episodeId. Message: $message");
      _uiService.showSuccessSnackbar(message);
    } catch (e, stackTrace) {
      _logger.e("Error toggling bookmark for commentary episode ID: $episodeId",
          e, stackTrace);
      setState(() => _episodeBookmarks[episodeId] = isCurrentlyBookmarked);
      _uiService.showErrorSnackbar('Error updating bookmark.');
    }
  }

  // --- PLAYLIST METHODS REFACTORED ---

  Future<void> _addEpisodeToPlaylist(int playlistId, int episodeId) async {
    _logger.i("Adding commentary episode $episodeId to playlist $playlistId");
    final token = _authProvider.token;
    if (token == null) {
      _uiService.showErrorSnackbar('Please log in to add to playlists.');
      return;
    }
    try {
      // Calling the new, cleaner service method
      await _playlistService.addEpisodeToPlaylist(
        token: token,
        playlistId: playlistId,
        episodeId: episodeId,
        type: _contentType, // ContentType.commentary
      );
      _uiService.showSuccessSnackbar('Added to playlist.');
    } catch (e) {
      _logger.e("Error adding commentary episode to playlist", e);
      _uiService.showErrorSnackbar('Error adding to playlist');
    }
  }

  Future<void> _createNewPlaylist(String name, int episodeId) async {
    _logger.i(
        "Creating new playlist '$name' and adding commentary episode $episodeId");
    final token = _authProvider.token;
    if (token == null) {
      _uiService.showErrorSnackbar('Please log in to create playlists.');
      return;
    }
    try {
      // Calling the new, cleaner service method
      await _playlistService.createNewPlaylistAndAddEpisode(
        token: token,
        newPlaylistName: name,
        episodeId: episodeId,
        type: _contentType,
      );
      _uiService.showSuccessSnackbar('Playlist created and episode added.');
    } catch (e) {
      _logger.e("Error creating new playlist for commentary episode", e);
      _uiService.showErrorSnackbar('Error creating playlist');
    }
  }

  // =======================================================================
  // === MODIFIED SECTION: Changed Bottom Sheet to a Centered Dialog ===
  // =======================================================================
  void _showAddToPlaylistDialog(int episodeId) {
    final token = _authProvider.token;
    if (token == null) {
      _uiService.showErrorSnackbar("Please log in to use playlists.");
      return;
    }

    // Use showDialog for a centered pop-up
    showDialog(
      context: context,
      builder: (dialogContext) {
        List<Playlist>? dialogPlaylists;
        bool dialogIsLoading = true;

        // StatefulBuilder is still needed to manage the loading state inside the dialog
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            // Fetch playlists only once when the dialog is built
            if (dialogPlaylists == null) {
              _playlistService
                  .fetchPlaylists(token: token)
                  .then((fetchedPlaylists) {
                if (mounted) {
                  setState(() {
                    dialogPlaylists = fetchedPlaylists;
                    dialogIsLoading = false;
                  });
                }
              }).catchError((e, stackTrace) {
                _logger.e("Failed to load playlists for dialog", e, stackTrace);
                if (mounted) {
                  Navigator.pop(dialogContext);
                  _uiService
                      .showErrorSnackbar("Could not load your playlists.");
                }
              });
            }

            // Return an AlertDialog
            return AlertDialog(
              title: const Text('Add to Playlist'),
              // Use SizedBox and Column to structure the content
              content: SizedBox(
                width: double.maxFinite, // Use available width
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Avoid vertical overflow
                  children: [
                    if (dialogIsLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (dialogPlaylists == null ||
                        dialogPlaylists!.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32.0),
                        child:
                            Center(child: Text('You have no playlists yet.')),
                      )
                    else
                      // Use Flexible to make the list scrollable if it's too long
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: dialogPlaylists!.length,
                          itemBuilder: (context, index) {
                            final playlist = dialogPlaylists![index];
                            final int itemCount = playlist.itemsCount ?? 0;
                            return ListTile(
                              leading: Icon(Icons.queue_music_rounded,
                                  color: Theme.of(context).primaryColor),
                              title: Text(playlist.name),
                              subtitle: Text(
                                  '$itemCount ${itemCount == 1 ? "item" : "items"}'),
                              onTap: () {
                                Navigator.pop(
                                    dialogContext); // Close the dialog
                                _addEpisodeToPlaylist(playlist.id, episodeId);
                              },
                            );
                          },
                        ),
                      ),
                    const Divider(height: 24),
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline),
                      title: const Text('Create new playlist'),
                      onTap: () {
                        Navigator.pop(dialogContext); // Close this dialog first
                        _showCreatePlaylistDialog(episodeId);
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                // Add a button to close the dialog
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(color: Colors.red), // Red cancel text
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- MODIFIED: Added red color to cancel button ---
  void _showCreatePlaylistDialog(int episodeId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Playlist Name",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.red), // Red cancel text
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext);
                _createNewPlaylist(controller.text, episodeId);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF009B77),
              foregroundColor: Colors.white,
            ),
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
  }
  // =======================================================================
  // === END OF MODIFIED SECTION ===
  // =======================================================================

  // --- HELPER & PLAYER METHODS (Unchanged) ---
  String _getTitle(Map<String, dynamic> item) =>
      item['title']?.toString() ?? item['name']?.toString() ?? 'Untitled';
  String? _getVideoPath(Map<String, dynamic> item) =>
      item['video']?.toString() ?? item['video_path']?.toString();
  String? _getAudioPath(Map<String, dynamic> item) =>
      item['audio']?.toString() ?? item['audio_path']?.toString();

  bool _isEpisodeLocked(dynamic episode) {
    if (episode is! Map) return false;
    bool parentRequiresPremium =
        (_content['is_premium'] == true || _content['is_premium'] == 1);
    bool episodeIsIndividuallyLocked =
        (episode['is_locked'] == true || episode['is_locked'] == 1);
    return (parentRequiresPremium || episodeIsIndividuallyLocked) &&
        !_isUserPremium;
  }

  void _navigateToSubscriptionPage() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SubscriptionPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  List<Map<String, String>> _convertEpisodesToPlayerMaps(
      List<dynamic>? episodes) {
    if (episodes == null) return [];
    List<Map<String, String>> list = [];
    for (var item in episodes) {
      if (item is Map) {
        final episodeIdStr = item['id']?.toString();
        final title = _getTitle(item as Map<String, dynamic>);
        final youtubeUrl = item['youtube_link']?.toString();
        if (episodeIdStr != null &&
            title.isNotEmpty &&
            youtubeUrl != null &&
            youtubeUrl.isNotEmpty) {
          final String? videoId = YoutubePlayer.convertUrlToId(youtubeUrl);
          final String thumbnailUrl = videoId != null
              ? YoutubePlayer.getThumbnail(videoId: videoId)
              : '';
          list.add({
            'id': episodeIdStr,
            'title': title,
            'url': youtubeUrl,
            'thumbnail': thumbnailUrl
          });
        }
      }
    }
    return list;
  }

  void _playVideo(dynamic episode) {
    _logger.i("Attempting to play video for episode: ${_getTitle(episode)}");
    final videoPath = _getVideoPath(episode);
    final playableUrl = _contentService.getPlayableUrl(videoPath);
    if (playableUrl == null) {
      _logger.w("Video not available for episode: ${_getTitle(episode)}");
      _uiService.showErrorSnackbar("Video is not available.");
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            VideoPlayerPage(
          videoUrl: playableUrl,
          episodeTitle: _getTitle(episode),
          episodeId: episode['id'],
          contentId: _parentId,
          contentType: _contentType.apiName,
          episodes: _episodes ?? [],
          otherEpisodes: _convertEpisodesToPlayerMaps(_episodes),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  void _playYoutube(dynamic episode) {
    _logger.i(
        "Attempting to play YouTube video for episode: ${_getTitle(episode)}");
    final youtubeUrl = episode['youtube_link']?.toString();
    if (youtubeUrl == null || youtubeUrl.isEmpty) {
      _logger
          .w("YouTube link not available for episode: ${_getTitle(episode)}");
      _uiService.showErrorSnackbar("YouTube link is not available.");
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            YouTubePlayerPage(
          initialYoutubeUrl: youtubeUrl,
          initialEpisodeTitle: _getTitle(episode),
          initialEpisodeId: episode['id'],
          contentId: _parentId,
          contentType: _contentType.apiName,
          otherEpisodes: _convertEpisodesToPlayerMaps(_episodes),
          youtubeUrl: youtubeUrl,
          episodeTitle: _getTitle(episode),
          episodeId: episode['id'],
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  void _playAudio(dynamic episode) {
    _logger.i("Attempting to play audio for episode: ${_getTitle(episode)}");
    final audioPath = _getAudioPath(episode);
    final playableUrl = _contentService.getPlayableUrl(audioPath);
    if (playableUrl == null) {
      _logger.w("Audio not available for episode: ${_getTitle(episode)}");
      _uiService.showErrorSnackbar("Audio is not available.");
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AudioPlayerPage(
          audioUrl: playableUrl,
          episodeTitle: _getTitle(episode),
          storyTitle: _getTitle(_content),
          imageUrl:
              _contentService.getPlayableUrl(_content[_contentType.imageKey]),
          episodeId: episode['id'],
          contentId: _parentId,
          contentType: _contentType.apiName,
          currentEpisodeId: episode['id'],
          episodes: _episodes ?? [],
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  void _playFirstAvailableMedia(dynamic episode) {
    _logger
        .i("Playing first available media for episode: ${_getTitle(episode)}");
    final videoPath = _getVideoPath(episode);
    final youtubeLink = episode['youtube_link']?.toString();
    final audioPath = _getAudioPath(episode);

    if (videoPath != null) {
      _playVideo(episode);
    } else if (youtubeLink != null && youtubeLink.isNotEmpty) {
      _playYoutube(episode);
    } else if (audioPath != null) {
      _playAudio(episode);
    } else {
      _logger.w("No playable media found for episode: ${_getTitle(episode)}");
      _uiService.showErrorSnackbar("No playable media found.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isNightMode = themeProvider.isDarkMode;
    final Color primaryColor = const Color(0xFF009B77);
    final Color scaffoldBgColor =
        isNightMode ? const Color(0xFF121212) : Colors.grey[50]!;

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      appBar: AppBar(
        title: Text(
          _getTitle(_content),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: isNightMode ? const Color(0xFF1E1E1E) : primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAllInitialData,
        color: primaryColor,
        backgroundColor: isNightMode ? const Color(0xFF2C2C2C) : Colors.white,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _isLoadingEpisodes
                  ? SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      ),
                    )
                  : _errorLoadingEpisodes != null
                      ? Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: _buildErrorState(
                              _errorLoadingEpisodes!, isNightMode),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(isNightMode),
                            if (_content['description'] != null &&
                                _content['description']
                                    .toString()
                                    .trim()
                                    .isNotEmpty)
                              _buildDescriptionSection(isNightMode),
                          ],
                        ),
            ),
            if (!_isLoadingEpisodes && _errorLoadingEpisodes == null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: _episodes == null || _episodes!.isEmpty
                    ? SliverToBoxAdapter(
                        child: _buildEmptyState(isNightMode),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final episode = _episodes![index];
                            final bool locked = _isEpisodeLocked(episode);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildEpisodeCard(
                                  episode, isNightMode, locked),
                            );
                          },
                          childCount: _episodes!.length,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  // --- BUILD HELPER WIDGETS (Unchanged) ---
  Widget _buildHeader(bool isNightMode) {
    final String? imageUrl = _content[_contentType.imageKey] as String?;
    final fullImageUrl = _contentService.getPlayableUrl(imageUrl);
    final bool hasImage = fullImageUrl != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: isNightMode ? Colors.grey[800] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.network(
                    fullImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 48,
                        color:
                            isNightMode ? Colors.grey[600] : Colors.grey[400],
                      ),
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: const Color(0xFF009B77),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          if (hasImage) const SizedBox(height: 16),
          Text(
            _getTitle(_content),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isNightMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(bool isNightMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About this Commentary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isNightMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _content['description']?.toString() ?? '',
            style: TextStyle(
              fontSize: 15,
              color: isNightMode ? Colors.white70 : Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Divider(color: isNightMode ? Colors.grey[700] : Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Episodes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isNightMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildEpisodeCard(dynamic episode, bool isNightMode, bool locked) {
    final int episodeId = int.parse(episode['id'].toString());
    return Card(
      elevation: locked ? 0.5 : 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: locked
          ? (isNightMode
              ? Colors.grey[850]!.withOpacity(0.6)
              : Colors.grey[200]!)
          : (isNightMode ? const Color(0xFF1E1E1E) : Colors.white),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: locked
            ? _navigateToSubscriptionPage
            : () => _playFirstAvailableMedia(episode),
        child: locked
            ? _buildLockedEpisodeContent(episode, isNightMode)
            : _buildUnlockedEpisodeContent(episode, isNightMode, episodeId),
      ),
    );
  }

  Widget _buildLockedEpisodeContent(dynamic episode, bool isNightMode) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: Colors.redAccent, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Premium Content',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getTitle(episode),
                  style: TextStyle(
                    color: isNightMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _navigateToSubscriptionPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockedEpisodeContent(
      dynamic episode, bool isNightMode, int episodeId) {
    final bool isBookmarked = _episodeBookmarks[episodeId] ?? false;
    final bool hasVideo = _getVideoPath(episode) != null ||
        (episode['youtube_link'] != null &&
            episode['youtube_link'].toString().isNotEmpty);
    final bool hasAudio = _getAudioPath(episode) != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  const Color(0xFF009B77).withOpacity(isNightMode ? 0.2 : 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Color(0xFF009B77),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTitle(episode),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isNightMode ? Colors.white : Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasVideo || hasAudio) const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (hasVideo)
                      _buildMediaTag(
                        icon: Icons.videocam_outlined,
                        label: 'Video',
                        isNightMode: isNightMode,
                        onTap: () => _playFirstAvailableMedia(episode),
                      ),
                    if (hasAudio)
                      _buildMediaTag(
                        icon: Icons.audiotrack_outlined,
                        label: 'Audio',
                        isNightMode: isNightMode,
                        onTap: () => _playAudio(episode),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildEpisodeMenu(episode, isNightMode, episodeId, isBookmarked),
        ],
      ),
    );
  }

  Widget _buildMediaTag({
    required IconData icon,
    required String label,
    required bool isNightMode,
    required VoidCallback onTap,
  }) {
    final Color tagColor = const Color(0xFF009B77);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: tagColor.withOpacity(isNightMode ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tagColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: tagColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: tagColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeMenu(
      dynamic episode, bool isNightMode, int episodeId, bool isBookmarked) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: isNightMode ? Colors.white70 : Colors.grey[600],
      ),
      onSelected: (value) {
        if (value == 'bookmark') {
          _toggleBookmark(episodeId);
        } else if (value == 'add_to_playlist') {
          _showAddToPlaylistDialog(episodeId);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'bookmark',
          child: Row(
            children: [
              Icon(
                isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: const Color(0xFF009B77),
              ),
              const SizedBox(width: 8),
              Text(isBookmarked ? 'Remove Bookmark' : 'Bookmark'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'add_to_playlist',
          child: Row(
            children: [
              Icon(
                Icons.playlist_add_rounded,
                color: const Color(0xFF009B77),
              ),
              const SizedBox(width: 8),
              const Text('Add to Playlist'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error, bool isNightMode) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
        const SizedBox(height: 16),
        Text(
          error,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: isNightMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _fetchAllInitialData,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF009B77),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isNightMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.playlist_play_outlined,
            size: 54,
            color: isNightMode ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No episodes yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isNightMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Episodes for this content will appear here when added.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isNightMode ? Colors.white70 : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
