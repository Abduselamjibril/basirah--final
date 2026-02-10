// lib/youtube_player_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pod_player/pod_player.dart';
import '../theme_provider.dart'; // Adjust path if necessary

// --- Screen Recording Prevention Imports ---
import 'dart:io' show Platform;
// NOTE: Screen recording prevention for iOS requires additional native setup.
// This code provides the Flutter-side logic.

const String _apiBaseUrl = "https://admin.basirahtv.com"; // Your API base URL
// Align accent color with Audio player
const Color _playerPrimaryColor = Color(0xFF009B77);

class YouTubePlayerPage extends StatefulWidget {
  final String initialYoutubeUrl;
  final String initialEpisodeTitle;
  final List<Map<String, dynamic>> otherEpisodes;
  final int initialEpisodeId;
  final int contentId;
  final String contentType;
  // These properties were duplicates and are covered by the 'initial' ones.
  // Kept for constructor compatibility but are not used internally.
  final String episodeTitle;
  final int episodeId;
  final String youtubeUrl;

  const YouTubePlayerPage({
    required this.initialYoutubeUrl,
    required this.initialEpisodeTitle,
    required this.otherEpisodes,
    required this.initialEpisodeId,
    required this.contentId,
    required this.contentType,
    // These are redundant but kept for API compatibility from the user's code.
    required this.episodeTitle,
    required this.episodeId,
    required this.youtubeUrl,
    Key? key,
  }) : super(key: key);

  @override
  _YouTubePlayerPageState createState() => _YouTubePlayerPageState();
}

class _YouTubePlayerPageState extends State<YouTubePlayerPage>
    with WidgetsBindingObserver {
  late PodPlayerController _podController;
  late String _currentYoutubeUrl;
  late String _currentEpisodeTitle;
  late int _currentEpisodeId;
  late final List<Map<String, dynamic>> _playlistEpisodes;

  // --- State Variables for Player Logic ---
  bool _isPlayerReady = false;
  PodVideoState? _playerState;
  bool _isDisposing = false;
  bool _isActiveInTree = true;
  Timer? _progressUpdateTimer;

  // --- Theme colors ---
  late Color _scaffoldBgColor;
  late Color _belowPlayerBgColor;
  late Color _videoTitleColor;
  late Color _playlistHeaderColor;
  late Color _dividerColor;
  late Color _currentPlaylistItemBgColor;
  late Color _currentPlaylistItemTextColor;
  late Color _defaultPlaylistItemTextColor;
  late Color _thumbnailPlaceholderBgColor;
  late Color _infoSnackbarBgColor;
  late Color _primaryColor;
  late Color _appBarColor;
  late Color _appBarIconColor;

  // --- Screen Recording State ---
  bool _isIOSScreenRecording = false;
  StreamSubscription<bool>? _iosScreenRecordingSubscription;
  bool _hasShownRecordingDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Normalize playlist data
    _playlistEpisodes = widget.otherEpisodes
        .map<Map<String, dynamic>>(_normalizeEpisode)
        .toList(growable: false);

    // Set initial episode data
    _currentEpisodeId = widget.initialEpisodeId;
    _currentEpisodeTitle = widget.initialEpisodeTitle;
    final cleanUrl = widget.initialYoutubeUrl.split('&').first;
    _currentYoutubeUrl = cleanUrl;

    // Initialize the PodPlayerController
    _podController = PodPlayerController(
      playVideoFrom: PlayVideoFrom.youtube(_currentYoutubeUrl),
      podPlayerConfig: const PodPlayerConfig(
        autoPlay: true,
        isLooping: false,
        videoQualityPriority: [720, 360],
      ),
    )..initialise();

    // Add listener for state changes (playing, paused, ended, etc.)
    _podController.addListener(_playerListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateThemeColors();
    });
  }

  @override
  void deactivate() {
    _isActiveInTree = false;
    _progressUpdateTimer?.cancel();
    super.deactivate();
  }

  @override
  void activate() {
    _isActiveInTree = true;
    super.activate();
  }

  Map<String, dynamic> _normalizeEpisode(Map<String, dynamic> episode) {
    return {
      'id': '${episode['id'] ?? episode['episode_id'] ?? ''}',
      'url': '${episode['url'] ?? episode['youtube_url'] ?? ''}',
      'youtube_url': '${episode['youtube_url'] ?? episode['url'] ?? ''}',
      'title': '${episode['title'] ?? episode['name'] ?? ''}',
      'name': '${episode['name'] ?? episode['title'] ?? ''}',
      'thumbnail_url':
          '${episode['thumbnail_url'] ?? episode['thumbnail'] ?? episode['image'] ?? ''}',
      'thumbnail':
          '${episode['thumbnail'] ?? episode['thumbnail_url'] ?? episode['image'] ?? ''}',
      'image': '${episode['image'] ?? episode['thumbnail'] ?? ''}',
    };
  }

  void _handleIOSScreenRecordingChange(bool isRecording) {
    if (!mounted) return;

    bool oldStatus = _isIOSScreenRecording;
    setState(() => _isIOSScreenRecording = isRecording);

    if (isRecording) {
      print(
          "[YouTubePlayerPage] iOS screen recording detected! Pausing video.");
      if (_podController.isVideoPlaying) {
        _podController.pause();
      }
      _showScreenRecordingWarningDialog();
    } else {
      if (oldStatus == true && isRecording == false) {
        print("[YouTubePlayerPage] iOS screen recording stopped.");
        if (_podController.isInitialised && !_isPlayerReady) {
          // Trigger the listener logic again if the player is ready but wasn't marked as such
          _playerListener();
        }
      }
    }
  }

  void _showScreenRecordingWarningDialog() {
    if (!mounted ||
        !Platform.isIOS ||
        !_isIOSScreenRecording ||
        _hasShownRecordingDialog) return;

    setState(() => _hasShownRecordingDialog = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final themeProvider =
            Provider.of<ThemeProvider>(context, listen: false);
        final isNightMode = themeProvider.isDarkMode;
        return AlertDialog(
          backgroundColor: isNightMode ? const Color(0xFF1E2A3A) : Colors.white,
          title: Text("Screen Recording Active",
              style: TextStyle(
                  color: isNightMode ? Colors.white : Colors.black87)),
          content: Text(
              "To protect our content, video playback is disabled while screen recording is active. Please stop recording to continue.",
              style: TextStyle(
                  color: isNightMode ? Colors.white70 : Colors.black54)),
          actions: <Widget>[
            TextButton(
              child: Text("OK", style: TextStyle(color: _primaryColor)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                setState(() {
                  _hasShownRecordingDialog = false;
                  _isIOSScreenRecording = false;
                });
              },
            ),
          ],
        );
      },
    );
  }

  void _updateThemeColors() {
    if (!mounted || _isDisposing || !_isActiveInTree) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isNightMode = themeProvider.isDarkMode;
    final ThemeData currentTheme = themeProvider.currentTheme;
    setState(() {
      _primaryColor = _playerPrimaryColor;
      _scaffoldBgColor = currentTheme.scaffoldBackgroundColor;
      _belowPlayerBgColor =
          isNightMode ? const Color(0xFF121212) : Colors.grey.shade50;
      _videoTitleColor = currentTheme.textTheme.titleLarge?.color ??
          (isNightMode ? Colors.white.withOpacity(0.95) : Colors.black87);
      _playlistHeaderColor =
          currentTheme.textTheme.titleMedium?.color?.withOpacity(0.8) ??
              (isNightMode ? Colors.white70 : Colors.black54);
      _dividerColor = currentTheme.dividerColor.withOpacity(0.5);
      _currentPlaylistItemBgColor = isNightMode
          ? Colors.grey[850]!
          : _playerPrimaryColor.withOpacity(0.08);
      _currentPlaylistItemTextColor = isNightMode
          ? currentTheme.colorScheme.secondary
          : currentTheme.primaryColorDark;
      _defaultPlaylistItemTextColor = currentTheme.textTheme.bodyLarge?.color ??
          (isNightMode
              ? Colors.white.withOpacity(0.9)
              : Colors.black.withOpacity(0.9));
      _thumbnailPlaceholderBgColor =
          isNightMode ? Colors.grey[800]! : Colors.grey[300]!;
      _infoSnackbarBgColor =
          isNightMode ? Colors.grey[700]! : _playerPrimaryColor;
      _appBarColor = currentTheme.scaffoldBackgroundColor;
      _appBarIconColor = isNightMode ? Colors.white : Colors.black54;
    });
  }

  void _handleInvalidUrl(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showErrorSnackbar(message);
      if (Navigator.canPop(context)) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
        });
      }
    });
  }

  // This listener is called whenever the player's state changes.
  void _playerListener() {
    if (!mounted) return;

    // Handle screen recording interruption
    if (Platform.isIOS &&
        _isIOSScreenRecording &&
        _podController.isVideoPlaying) {
      _podController.pause();
      _showScreenRecordingWarningDialog();
      return;
    }

    final bool wasPlayerLogicReady = _isPlayerReady;
    final PodVideoState currentControllerState = _podController.videoState;

    // Check if player is initialized and ready for interactions
    if (_podController.isInitialised &&
        !(Platform.isIOS && _isIOSScreenRecording)) {
      if (!_isPlayerReady) {
        if (mounted) setState(() => _isPlayerReady = true);
      }
    } else {
      if (_isPlayerReady) {
        if (mounted) setState(() => _isPlayerReady = false);
      }
    }

    // Actions to perform when the player first becomes ready
    if (_isPlayerReady && !wasPlayerLogicReady) {
      _updateEpisodeProgress(_currentEpisodeId);
      if (currentControllerState == PodVideoState.playing) {
        _startPeriodicProgressUpdates();
      }
    }

    // Handle player state changes (playing, paused, ended, etc.)
    if (_isPlayerReady && currentControllerState != _playerState) {
      if (mounted) setState(() => _playerState = currentControllerState);
      if (_playerState == PodVideoState.playing) {
        _startPeriodicProgressUpdates();
      } else if (_playerState == PodVideoState.paused &&
          _podController.currentVideoPosition > Duration.zero) {
        // Detect if video ended: paused and at (or near) end
        final pos = _podController.currentVideoPosition;
        final total = _podController.totalVideoLength;
        final isEnded =
            total.inSeconds > 0 && (total.inSeconds - pos.inSeconds).abs() <= 1;
        _progressUpdateTimer?.cancel();
        _sendProgressUpdate(isCompleted: isEnded);
        if (isEnded) {
          if (!mounted || (Platform.isIOS && _isIOSScreenRecording)) return;
          _playNextEpisode();
        }
      } else {
        _progressUpdateTimer?.cancel();
      }
    }

    // Log errors if any
    if (_podController.videoPlayerValue?.hasError ?? false) {
      debugPrint(
          '[YouTubePlayerPage] Pod Player Error: ${_podController.videoPlayerValue?.errorDescription}');
    }
  }

  Future<void> _updateEpisodeProgress(int episodeId) async {
    await _sendProgressUpdate();
  }

  Future<String?> _getPhoneNumber() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getString('userPhoneNumber');
    } catch (e) {
      print("[YouTubePlayerPage] Error getting phone number: $e");
      return null;
    }
  }

  void _startPeriodicProgressUpdates() {
    _progressUpdateTimer?.cancel();
    if (_isPlayerReady &&
        _podController.isVideoPlaying &&
        _isActiveInTree &&
        !_isDisposing) {
      _progressUpdateTimer =
          Timer.periodic(const Duration(seconds: 15), (timer) {
        if (mounted &&
            _isActiveInTree &&
            !_isDisposing &&
            _podController.isVideoPlaying) {
          if (!(Platform.isIOS && _isIOSScreenRecording)) {
            _sendProgressUpdate();
          }
        } else {
          timer.cancel();
        }
      });
    }
  }

  Future<void> _sendProgressUpdate({bool isCompleted = false}) async {
    if (_isDisposing || !_isActiveInTree) return;
    if (!_isPlayerReady && !isCompleted) return;
    if (Platform.isIOS && _isIOSScreenRecording && !isCompleted) return;

    final phoneNumber = await _getPhoneNumber();
    if (phoneNumber == null) return;

    final currentPositionSeconds =
        _podController.currentVideoPosition.inSeconds;
    final totalDurationSeconds = _podController.totalVideoLength.inSeconds;

    final bool nearEnd = totalDurationSeconds > 0 &&
        (totalDurationSeconds - currentPositionSeconds) < 5;
    if (currentPositionSeconds <= 0 &&
        !isCompleted &&
        !nearEnd &&
        totalDurationSeconds > 5) return;

    final body = json.encode({
      'phone_number': phoneNumber,
      'episode_id': _currentEpisodeId,
      'content_id': widget.contentId,
      'content_type': widget.contentType,
      'current_position_seconds': currentPositionSeconds,
      if (isCompleted) 'is_completed': true,
      if (totalDurationSeconds > 0)
        'total_duration_seconds': totalDurationSeconds,
    });
    try {
      await http
          .post(Uri.parse('$_apiBaseUrl/api/progress/update'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
              },
              body: body)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      /* Handled gracefully */
    }
  }

  void _playNextEpisode() {
    if (Platform.isIOS && _isIOSScreenRecording) {
      _showScreenRecordingWarningDialog();
      return;
    }
    final currentIndex = _playlistEpisodes.indexWhere(
        (ep) => int.tryParse(ep['id'] ?? '-1') == _currentEpisodeId);
    if (currentIndex != -1 && currentIndex < _playlistEpisodes.length - 1) {
      _playEpisode(_playlistEpisodes[currentIndex + 1]);
    } else {
      if (mounted) _showInfoSnackbar("You've reached the end of the playlist.");
    }
  }

  void _playEpisode(Map<String, dynamic> episode) {
    if (Platform.isIOS && _isIOSScreenRecording) {
      _showScreenRecordingWarningDialog();
      return;
    }
    final String url = '${episode['url'] ?? episode['youtube_url'] ?? ''}';
    final String title = '${episode['title'] ?? episode['name'] ?? ''}';
    final String idStr = '${episode['id'] ?? ''}';

    if (url.isEmpty || title.isEmpty || idStr.isEmpty) {
      if (mounted) {
        _showErrorSnackbar("Cannot play episode: data is incomplete.");
      }
      return;
    }
    final int? episodeId = int.tryParse(idStr);
    if (episodeId == null) {
      if (mounted) {
        _showErrorSnackbar("Cannot play episode: invalid episode ID format.");
      }
      return;
    }

    // pod_player can handle full YouTube URLs, no ID conversion needed.
    if (!url.contains('youtu')) {
      if (mounted) {
        _showErrorSnackbar("Cannot play '$title': Invalid YouTube URL.");
      }
      return;
    }

    if (mounted) {
      if (_isPlayerReady) _sendProgressUpdate();
      setState(() {
        _currentYoutubeUrl = url;
        _currentEpisodeTitle = title;
        _currentEpisodeId = episodeId;
        _isPlayerReady = false; // Player will re-initialize
        _playerState = PodVideoState.loading;
      });
    }
    try {
      // Use changeVideo to load a new source into the existing player
      _podController.changeVideo(playVideoFrom: PlayVideoFrom.youtube(url));
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar("Could not load video. Please try again.");
      }
    }
    if (mounted && _isActiveInTree && !_isDisposing) {
      FocusScope.of(context).unfocus();
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted || _isDisposing || !_isActiveInTree) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final Color errorBgColor = Colors.redAccent.shade700;
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: errorBgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 30),
      dismissDirection: DismissDirection.horizontal,
    ));
  }

  void _showInfoSnackbar(String message) {
    if (!mounted || _isDisposing || !_isActiveInTree) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _infoSnackbarBgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 30),
      duration: const Duration(seconds: 2),
      dismissDirection: DismissDirection.horizontal,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;
    // Pause the video when the app goes into the background
    if (state == AppLifecycleState.paused &&
        _isPlayerReady &&
        _podController.isVideoPlaying) {
      _podController.pause();
      if (!(Platform.isIOS && _isIOSScreenRecording)) _sendProgressUpdate();
    }
  }

  @override
  void dispose() {
    _isDisposing = true;
    WidgetsBinding.instance.removeObserver(this);
    _iosScreenRecordingSubscription?.cancel();
    _progressUpdateTimer?.cancel();

    // Send final progress update before disposing
    if (_isPlayerReady &&
        (_podController.currentVideoPosition > Duration.zero)) {
      if (!(Platform.isIOS && _isIOSScreenRecording)) _sendProgressUpdate();
    }

    // Ensure the app exits fullscreen mode if the page is disposed while in fullscreen
    if (_podController.isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }

    // Remove the listener and dispose of the controller to free up resources
    _podController.removeListener(_playerListener);
    _podController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _updateThemeColors();
    final bool hideUIForRecording = Platform.isIOS && _isIOSScreenRecording;
    final bool enablePlaylistTapInteraction = !hideUIForRecording;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentEpisodeTitle,
          style: TextStyle(
            color: _appBarIconColor, // Use consistent icon color for title
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: _appBarColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _appBarIconColor),
      ),
      backgroundColor: _scaffoldBgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: hideUIForRecording
                  ? _buildScreenRecordingOverlay()
                  : PodVideoPlayer(
                      controller: _podController,
                      podPlayerLabels: const PodPlayerLabels(
                        quality: 'Quality',
                      ),
                    ),
            ),
            Expanded(
              child: Container(
                color: _belowPlayerBgColor,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildVideoInfo(),
                      _buildPlaylist(enablePlaylistTapInteraction),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenRecordingOverlay() {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_outlined,
                color: Colors.yellow.shade700, size: 50),
            const SizedBox(height: 20),
            const Text("Playback Disabled",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text(
                "Screen recording is active. Please stop recording to watch the video.",
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoInfo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Text(_currentEpisodeTitle,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _videoTitleColor),
          maxLines: 2,
          overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildPlaylist(bool enableTap) {
    final playlistItems = _playlistEpisodes;
    if (playlistItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text("Up next",
              style: TextStyle(
                  color: _playlistHeaderColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
        ),
        Divider(
            color: _dividerColor,
            height: 1,
            thickness: 1,
            indent: 16,
            endIndent: 16),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: playlistItems.length,
          itemBuilder: (context, index) =>
              _buildPlaylistItem(playlistItems[index], index, enableTap),
        ),
      ],
    );
  }

  Widget _buildPlaylistItem(
      Map<String, dynamic> episode, int index, bool enableTap) {
    final int? episodeId = int.tryParse('${episode['id'] ?? ''}');
    final bool isCurrent = episodeId != null && episodeId == _currentEpisodeId;
    final String thumbnailUrl =
        '${episode['thumbnail_url'] ?? episode['thumbnail'] ?? episode['image'] ?? ''}';
    final String title =
        '${episode['title'] ?? episode['name'] ?? 'Untitled Episode'}';
    final bool isThumbnailValid = thumbnailUrl.isNotEmpty &&
        (thumbnailUrl.startsWith('http://') ||
            thumbnailUrl.startsWith('https://'));

    final Color itemTextColor = isCurrent
        ? _currentPlaylistItemTextColor
        : _defaultPlaylistItemTextColor;
    final Color itemBgColor =
        isCurrent ? _currentPlaylistItemBgColor : Colors.transparent;
    final Color indicatorColor = isCurrent ? _primaryColor : Colors.transparent;

    return Material(
      color: itemBgColor,
      child: InkWell(
        onTap: isCurrent || !enableTap ? null : () => _playEpisode(episode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          decoration: BoxDecoration(
              border:
                  Border(left: BorderSide(color: indicatorColor, width: 4.0))),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Container(
                      width: 120,
                      height: 68,
                      color: _thumbnailPlaceholderBgColor,
                      child: isThumbnailValid
                          ? Image.network(
                              thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, st) => const Center(
                                  child: Icon(Icons.hide_image_outlined)),
                            )
                          : const Center(
                              child: Icon(Icons.smart_display_rounded)),
                    ),
                  ),
                  if (isCurrent &&
                      _isPlayerReady &&
                      _playerState == PodVideoState.playing &&
                      !(Platform.isIOS && _isIOSScreenRecording))
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                          color: Colors.black.withOpacity(0.5),
                        ),
                        child: const Icon(Icons.bar_chart_rounded,
                            color: Colors.white, size: 28),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: itemTextColor,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.w500,
                        fontSize: 15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
