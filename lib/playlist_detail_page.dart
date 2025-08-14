// lib/pages/playlist/playlist_detail_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../media/audio_player_page.dart';
import '../../media/video_player_page.dart';
import '../../media/youtube_player_page.dart';
import '../../models/playlist/generic_episode.dart';
import '../../models/playlist/playlist.dart';
import '../../models/playlist/playlist_item.dart';
import '../../providers/auth_provider.dart';
import '../../services/content_detail_services/api_service.dart';
import '../../services/content_detail_services/content_service.dart';
import '../../services/content_detail_services/playlist_service.dart';
import '../../services/content_detail_services/ui_service.dart';
import '../../services/content_detail_services/user_service.dart';
import '../../theme_provider.dart';
import '../topbar/subscription_page.dart';

class PlaylistDetailPage extends StatefulWidget {
  final int playlistId;
  final String playlistName;

  const PlaylistDetailPage({
    required this.playlistId,
    required this.playlistName,
    Key? key,
  }) : super(key: key);

  @override
  _PlaylistDetailPageState createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  Playlist? _playlist;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isUserPremium = false;

  late final PlaylistService _playlistService;
  late final ContentService _contentService;
  late final UserService _userService;
  late final UIService _uiService;

  @override
  void initState() {
    super.initState();
    _playlistService = PlaylistService(ApiService());
    _contentService = ContentService(ApiService());
    _userService = UserService();
    _uiService = UIService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  int? _getStatusCodeFromException(Object e) {
    final message = e.toString().toLowerCase();
    if (message.contains('403')) return 403;
    if (message.contains('404')) return 404;
    return null;
  }

  Future<void> _initialize() async {
    if (!context.mounted) return;
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please log in to view this playlist.';
      });
      return;
    }
    setState(() => _isLoading = true);
    try {
      final premiumFuture = _userService.isUserPremium();
      final playlistFuture = _fetchPlaylistDetails(token);
      _isUserPremium = await premiumFuture;
      await playlistFuture;
    } catch (e) {
      if (context.mounted) {
        setState(() => _errorMessage = "An error occurred. Please try again.");
      }
    } finally {
      if (context.mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchPlaylistDetails(String token) async {
    if (context.mounted) {
      setState(() {
        _errorMessage = null;
      });
    }
    try {
      final playlist = await _playlistService.fetchPlaylistDetails(
        playlistId: widget.playlistId,
        token: token,
      );
      if (context.mounted) {
        setState(() => _playlist = playlist);
      }
    } catch (e) {
      if (!context.mounted) return;
      final statusCode = _getStatusCodeFromException(e);
      if (statusCode == 403 || statusCode == 404) {
        _uiService.showErrorSnackbar('This playlist is no longer available.');
        Navigator.of(context).pop();
      } else {
        setState(() => _errorMessage = "Failed to load playlist details.");
      }
    }
  }

  Future<void> _removePlaylistItem(PlaylistItem itemToRemove) async {
    if (!context.mounted) return;
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) {
      _uiService.showErrorSnackbar('Please log in to modify the playlist.');
      return;
    }
    final indexToRemove = _playlist!.items!.indexOf(itemToRemove);
    if (indexToRemove == -1) return;
    setState(() => _playlist!.items!.removeAt(indexToRemove));
    try {
      await _playlistService.removeEpisodeFromPlaylist(
        playlistId: widget.playlistId,
        playlistItemId: itemToRemove.itemId,
        token: token,
      );
      _uiService.showSuccessSnackbar('Episode removed from playlist.');
    } catch (e) {
      if (!context.mounted) return;
      final statusCode = _getStatusCodeFromException(e);
      if (statusCode == 403 || statusCode == 404) {
        _uiService.showSuccessSnackbar('Item was already removed.');
        return;
      }
      setState(() => _playlist!.items!.insert(indexToRemove, itemToRemove));
      _uiService
          .showErrorSnackbar('Failed to remove episode. Please try again.');
    }
  }

  bool _isEpisodeLocked(GenericEpisode episode) {
    return episode.isLocked && !_isUserPremium;
  }

  void _navigateToSubscriptionPage() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const SubscriptionPage()));
  }

  void _playFirstAvailableMedia(GenericEpisode episode) {
    if (episode.videoUrl != null && episode.videoUrl!.isNotEmpty) {
      _playVideo(episode);
    } else if (episode.youtubeLink != null && episode.youtubeLink!.isNotEmpty) {
      _playYoutube(episode);
    } else if (episode.audioUrl != null && episode.audioUrl!.isNotEmpty) {
      _playAudio(episode);
    } else {
      _uiService.showErrorSnackbar('No playable media found for this item.');
    }
  }

  List<dynamic> _getEpisodesForPlayer() {
    return _playlist?.items
            ?.where((item) => !item
                .episode.isDeleted) // Filter out deleted items for the player
            .map((item) {
          return {
            'id': item.episode.id,
            'title': item.episode.title,
            'name': item.episode.title,
            'video': item.episode.videoUrl,
            'video_path': item.episode.videoUrl,
            'audio': item.episode.audioUrl,
            'audio_path': item.episode.audioUrl,
            'youtube_link': item.episode.youtubeLink,
            'is_locked': item.episode.isLocked,
            'type': item.episode.type,
            'image_path': item.episode.imageUrl,
            '${item.episode.type}_id': item.episode.parentId,
          };
        }).toList() ??
        [];
  }

  void _playVideo(GenericEpisode episode) {
    final playableUrl = _contentService.getPlayableUrl(episode.videoUrl);
    if (playableUrl == null) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => VideoPlayerPage(
                  videoUrl: playableUrl,
                  episodeTitle: episode.title,
                  episodeId: episode.id,
                  contentId: episode.parentId,
                  contentType: episode.type,
                  episodes: _getEpisodesForPlayer(),
                  otherEpisodes: [],
                )));
  }

  void _playYoutube(GenericEpisode episode) {
    if (episode.youtubeLink == null) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => YouTubePlayerPage(
                  initialYoutubeUrl: episode.youtubeLink!,
                  initialEpisodeTitle: episode.title,
                  initialEpisodeId: episode.id,
                  contentId: episode.parentId,
                  contentType: episode.type,
                  otherEpisodes: [],
                  youtubeUrl: episode.youtubeLink!,
                  episodeTitle: episode.title,
                  episodeId: episode.id,
                )));
  }

  void _playAudio(GenericEpisode episode) {
    final playableUrl = _contentService.getPlayableUrl(episode.audioUrl);
    if (playableUrl == null) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AudioPlayerPage(
                  audioUrl: playableUrl,
                  episodeTitle: episode.title,
                  storyTitle: _playlist?.name ?? 'Playlist',
                  imageUrl: _contentService.getPlayableUrl(episode.imageUrl),
                  episodeId: episode.id,
                  contentId: episode.parentId,
                  contentType: episode.type,
                  currentEpisodeId: episode.id,
                  episodes: _getEpisodesForPlayer(),
                )));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isNightMode = themeProvider.isDarkMode;
    final primaryColor = const Color(0xFF009B77);
    final scaffoldBgColor =
        isNightMode ? const Color(0xFF121212) : Colors.grey[50]!;
    final List<PlaylistItem> currentItems = _playlist?.items ?? [];

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      appBar: AppBar(
        title: Text(_playlist?.name ?? widget.playlistName,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: isNightMode ? const Color(0xFF1E1E1E) : primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor)))
          : _errorMessage != null
              ? _buildErrorView(isNightMode)
              : RefreshIndicator(
                  onRefresh: _initialize,
                  color: primaryColor,
                  child: currentItems.isEmpty
                      ? _buildEmptyState(isNightMode)
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: currentItems.length,
                          itemBuilder: (context, index) {
                            final item = currentItems[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildItemCard(
                                  item, isNightMode), // Main card builder
                            );
                          },
                        ),
                ),
    );
  }

  /// --- FIX: This new method decides which card to render ---
  Widget _buildItemCard(PlaylistItem item, bool isNightMode) {
    // First, check if the item's episode is marked as deleted
    if (item.episode.isDeleted) {
      return _buildDeletedItemCard(item, isNightMode);
    }
    // Otherwise, render the locked/unlocked card as before
    final bool locked = _isEpisodeLocked(item.episode);
    return Card(
      elevation: locked ? 0.5 : 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: locked
          ? (isNightMode
              ? Colors.grey[850]!.withOpacity(0.6)
              : Colors.grey[200]!)
          : (isNightMode ? const Color(0xFF1E1E1E) : Colors.white),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: locked
            ? _navigateToSubscriptionPage
            : () => _playFirstAvailableMedia(item.episode),
        child: locked
            ? _buildLockedEpisodeContent(item.episode, isNightMode)
            : _buildUnlockedEpisodeContent(item, isNightMode),
      ),
    );
  }

  /// --- FIX: New widget to display an orphaned/deleted playlist item ---
  Widget _buildDeletedItemCard(PlaylistItem item, bool isNightMode) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.withOpacity(0.3)),
      ),
      color: isNightMode ? Colors.red.withOpacity(0.1) : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: Colors.red.shade400, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                item.episode.title, // Shows "Content no longer available"
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _removePlaylistItem(item),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );
  }

  // --- The rest of the build helpers are unchanged ---

  Widget _buildLockedEpisodeContent(GenericEpisode episode, bool isNightMode) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(children: [
        Icon(Icons.lock_outline_rounded, color: Colors.redAccent, size: 32),
        const SizedBox(width: 16),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Premium Content',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
            Text(episode.title,
                style: TextStyle(
                    color: isNightMode ? Colors.white70 : Colors.black54)),
          ]),
        ),
        ElevatedButton(
          onPressed: _navigateToSubscriptionPage,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
          child: const Text('Subscribe'),
        ),
      ]),
    );
  }

  Widget _buildUnlockedEpisodeContent(PlaylistItem item, bool isNightMode) {
    final episode = item.episode;
    final bool hasVideo =
        episode.videoUrl != null && episode.videoUrl!.isNotEmpty;
    final bool hasAudio =
        episode.audioUrl != null && episode.audioUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color:
                  const Color(0xFF009B77).withOpacity(isNightMode ? 0.2 : 0.1),
              shape: BoxShape.circle),
          child: const Icon(Icons.play_arrow_rounded,
              color: Color(0xFF009B77), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              episode.title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isNightMode ? Colors.white : Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (hasVideo || hasAudio) const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (hasVideo)
                _buildMediaTag(
                    icon: Icons.videocam_outlined,
                    label: 'Video',
                    isNightMode: isNightMode,
                    onTap: () => _playFirstAvailableMedia(episode)),
              if (hasAudio)
                _buildMediaTag(
                    icon: Icons.audiotrack_outlined,
                    label: 'Audio',
                    isNightMode: isNightMode,
                    onTap: () => _playAudio(episode)),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        _buildEpisodeMenu(item, isNightMode),
      ]),
    );
  }

  Widget _buildMediaTag(
      {required IconData icon,
      required String label,
      required bool isNightMode,
      required VoidCallback onTap}) {
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
            border: Border.all(color: tagColor.withOpacity(0.3), width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: tagColor),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: tagColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _buildEpisodeMenu(PlaylistItem item, bool isNightMode) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert,
          color: isNightMode ? Colors.white70 : Colors.grey[600]),
      onSelected: (value) {
        if (value == 'remove') {
          _showDeleteConfirmationDialog(item);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'remove',
          child: Row(children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
            const SizedBox(width: 8),
            const Text('Remove from Playlist'),
          ]),
        ),
      ],
    );
  }

  void _showDeleteConfirmationDialog(PlaylistItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Playlist?'),
        content: Text(
            'Are you sure you want to remove "${item.episode.title}" from this playlist?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removePlaylistItem(item);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(bool isNightMode) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    color: isNightMode ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _initialize, child: const Text('Retry'))
          ])));

  Widget _buildEmptyState(bool isNightMode) => LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Container(
              height: constraints.maxHeight,
              alignment: Alignment.center,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.playlist_play_outlined,
                        size: 70,
                        color:
                            isNightMode ? Colors.grey[600] : Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('Playlist is Empty',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color:
                                isNightMode ? Colors.white : Colors.black87)),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Text(
                          'Add episodes from any content to see them here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: isNightMode
                                  ? Colors.white70
                                  : Colors.grey[700])),
                    )
                  ]),
            ),
          ));
}
