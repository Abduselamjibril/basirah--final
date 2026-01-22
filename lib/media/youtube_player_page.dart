// lib/youtube_player_page.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart'; // Import logger
import 'package:pod_player/pod_player.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme_provider.dart'; // Adjust path if necessary

// Screen recording prevention has been removed.

const String _apiBaseUrl = "https://admin.basirahtv.com"; // Your API base URL

class YouTubePlayerPage extends StatefulWidget {
  final String initialYoutubeUrl;
  final String initialEpisodeTitle;
  final List<Map<String, String>> otherEpisodes;
  final int initialEpisodeId;
  final int contentId;
  final String contentType;
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
  // Initialize the logger
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 1, // Number of method calls to be displayed
      errorMethodCount: 5, // Number of method calls if stacktrace is provided
      lineLength: 100, // Width of the log print
      colors: true, // Colorful log messages
      printEmojis: true, // Print an emoji for each log message
      printTime: false, // Should each log print contain a timestamp
    ),
  );

  late PodPlayerController _podController;
  late String _currentVideoUrl;
  late String _currentEpisodeTitle;
  late int _currentEpisodeId;
  bool _isFullScreen = false;

  bool _isPlayerReady = false;
  bool _isPlaying = false;
  bool _hasMarkedCompleted = false;
  bool _doubleTapConfigured = false;
  Timer? _progressUpdateTimer;
  bool _isDisposing = false;
  bool _controllerReady = false;

  // Playback tuning & prefetch
  final List<int> _qualityPriority = const [360, 480, 720, 1080];
  final Map<int, String> _prefetchedUrlByEpisodeId = {};
  int? _prefetchedForEpisodeId;
  String? _currentThumbnailUrl;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _currentEpisodeId = widget.initialEpisodeId;
    _currentEpisodeTitle = widget.initialEpisodeTitle;
    final initialVideoUrl = _validateYoutubeUrl(widget.initialYoutubeUrl);

    if (initialVideoUrl == null) {
      _logger.e(
          "Invalid initial YouTube URL provided: ${widget.initialYoutubeUrl}");
      _currentVideoUrl = 'https://youtu.be/dQw4w9WgXcQ'; // Fallback video URL
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleInvalidUrl("Invalid initial YouTube URL provided.");
      });
    } else {
      _currentVideoUrl = initialVideoUrl;
    }

    _logger.i(
      'Initializing player for episode "${widget.initialEpisodeTitle}" (ID: $_currentEpisodeId) with URL: $_currentVideoUrl',
    );

    _currentThumbnailUrl = _youtubeThumbFromUrl(_currentVideoUrl);

    _initPodController(_currentVideoUrl);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateThemeColors();
    });
  }

  void _updateThemeColors() {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isNightMode = themeProvider.isDarkMode;
    final ThemeData currentTheme = themeProvider.currentTheme;
    setState(() {
      _primaryColor = currentTheme.primaryColor;
      _scaffoldBgColor = currentTheme.scaffoldBackgroundColor;
      _belowPlayerBgColor =
          isNightMode ? const Color(0xFF121212) : Colors.grey.shade50;
      _videoTitleColor = currentTheme.textTheme.titleLarge?.color ??
          (isNightMode ? Colors.white.withOpacity(0.95) : Colors.black87);
      _playlistHeaderColor =
          currentTheme.textTheme.titleMedium?.color?.withOpacity(0.8) ??
              (isNightMode ? Colors.white70 : Colors.black54);
      _dividerColor = currentTheme.dividerColor.withOpacity(0.5);
      _currentPlaylistItemBgColor =
          isNightMode ? Colors.grey[850]! : _primaryColor.withOpacity(0.08);
      _currentPlaylistItemTextColor = isNightMode
          ? currentTheme.colorScheme.secondary
          : currentTheme.primaryColorDark;
      _defaultPlaylistItemTextColor = currentTheme.textTheme.bodyLarge?.color ??
          (isNightMode
              ? Colors.white.withOpacity(0.9)
              : Colors.black.withOpacity(0.9));
      _thumbnailPlaceholderBgColor =
          isNightMode ? Colors.grey[800]! : Colors.grey[300]!;
      _infoSnackbarBgColor = isNightMode ? Colors.grey[700]! : _primaryColor;
      _appBarColor = currentTheme.scaffoldBackgroundColor;
      _appBarIconColor = isNightMode ? Colors.white : Colors.black54;
    });
  }

  void _handleInvalidUrl(String message) {
    _logger.w("Handling invalid URL: $message");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canShowUI()) return;
      _showErrorSnackbar(message);
      if (Navigator.canPop(context)) {
        Future.delayed(const Duration(seconds: 2), () {
          if (_canShowUI() && Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        });
      }
    });
  }

  void _podListener() {
    if (!mounted) return;

    final bool readyNow = _podController.isInitialised;
    if (readyNow && !_isPlayerReady) {
      _logger.i(
          "Player is now ready. State: ${_podController.isVideoPlaying ? 'playing' : 'idle'}");
      if (mounted) setState(() => _isPlayerReady = true);
      _updateEpisodeProgress(_currentEpisodeId);
      if (_podController.isVideoPlaying) {
        _startPeriodicProgressUpdates();
      }

      // One-time per (re)initialization adjustments
      if (!_doubleTapConfigured) {
        try {
          _podController.setDoubeTapForwarDuration(10);
          _doubleTapConfigured = true;
        } catch (_) {}
      }

      // Listen for quality changes
      try {
        _podController.onVideoQualityChanged(() {
          _logger.d('Video quality changed');
          if (_canShowUI()) {
            _showInfoSnackbar('Quality changed');
          }
        });
      } catch (_) {}

      // Prefetch next episode stream (best-effort)
      _prefetchNextEpisode();
    } else if (!readyNow && _isPlayerReady) {
      if (mounted) setState(() => _isPlayerReady = false);
    }

    final bool isPlayingNow = _podController.isVideoPlaying;
    if (isPlayingNow != _isPlaying) {
      if (mounted) setState(() => _isPlaying = isPlayingNow);
      if (isPlayingNow) {
        _startPeriodicProgressUpdates();
      } else {
        _progressUpdateTimer?.cancel();
        if (_podController.currentVideoPosition > Duration.zero) {
          _sendProgressUpdate();
        }
      }
    }

    final bool isFullScreenNow = _podController.isFullScreen;
    if (isFullScreenNow != _isFullScreen) {
      if (mounted) setState(() => _isFullScreen = isFullScreenNow);
      // Smooth orientation/UI adjustments to reduce visual distortion during transitions.
      unawaited(_applyFullScreenUi(isFullScreenNow));
    }

    _checkIfCompleted();
  }

  Future<void> _updateEpisodeProgress(int episodeId) async {
    await _sendProgressUpdate();
  }

  Future<void> _initPodController(String url) async {
    final playFrom = await _resolveInitialSource(url);
    if (!mounted) return;
    _podController = PodPlayerController(
      playVideoFrom: playFrom,
      podPlayerConfig: PodPlayerConfig(
        autoPlay: true,
        isLooping: false,
        videoQualityPriority: _qualityPriority,
        wakelockEnabled: true,
      ),
    );
    _podController.addListener(_podListener);
    await _podController.initialise();
    if (!mounted) return;
    setState(() {
      _controllerReady = true;
    });
  }

  Future<String?> _getPhoneNumber() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getString('userPhoneNumber');
    } catch (e) {
      _logger.e("Error getting phone number from SharedPreferences", e);
      return null;
    }
  }

  void _startPeriodicProgressUpdates() {
    _progressUpdateTimer?.cancel();
    if (_isPlayerReady && _podController.isVideoPlaying) {
      _logger.d("Starting periodic progress updates every 15 seconds.");
      _progressUpdateTimer =
          Timer.periodic(const Duration(seconds: 15), (timer) {
        if (mounted && _podController.isVideoPlaying) {
          _sendProgressUpdate();
          _checkIfCompleted();
        } else {
          _logger.d("Stopping periodic progress updates.");
          timer.cancel();
        }
      });
    }
  }

  void _checkIfCompleted() {
    if (!_isPlayerReady) return;
    final duration = _podController.totalVideoLength;
    final position = _podController.currentVideoPosition;
    if (duration == Duration.zero) return;

    final bool nearEnd = (duration.inSeconds - position.inSeconds) <= 1 &&
        duration > Duration.zero;
    if (nearEnd && !_hasMarkedCompleted) {
      _hasMarkedCompleted = true;
      _logger
          .i("Playback reached the end; sending completion and moving next.");
      _sendProgressUpdate(isCompleted: true);
      _playNextEpisode();
    } else if (!nearEnd) {
      _hasMarkedCompleted = false;
    }
  }

  Future<void> _sendProgressUpdate(
      {bool isCompleted = false, bool showErrors = true}) async {
    if (!_isPlayerReady && !isCompleted) return;

    final phoneNumber = await _getPhoneNumber();
    if (phoneNumber == null) {
      _logger.w("Cannot send progress update: Phone number is null.");
      return;
    }

    final currentPositionSeconds =
        _podController.currentVideoPosition.inSeconds;
    final totalDurationSeconds = _podController.totalVideoLength.inSeconds;

    // Avoid sending noisy updates when playback hasn't started or metadata is unknown.
    if (!isCompleted) {
      if (currentPositionSeconds <= 0) {
        _logger.d("Skipping progress update: position at 0s.");
        return;
      }
      if (totalDurationSeconds <= 0) {
        _logger.d("Skipping progress update: duration metadata unavailable.");
        return;
      }
      final bool nearEnd = (totalDurationSeconds - currentPositionSeconds) < 5;
      if (!nearEnd && totalDurationSeconds > 5 && currentPositionSeconds <= 0) {
        _logger.d("Skipping progress update at the beginning of the video.");
        return;
      }
    }

    _logger.i(
      'Sending progress update for Episode ID: $_currentEpisodeId at ${currentPositionSeconds}s. Completed: $isCompleted',
    );

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
      final response = await http
          .post(Uri.parse('$_apiBaseUrl/api/progress/update'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
              },
              body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        _logger.w("Authentication failed. User may need to log in again.");
        if (showErrors && _canShowUI()) {
          _showErrorSnackbar("Session expired. Please log in again.");
        }
      } else if (response.statusCode >= 400) {
        _logger.w(
            "Progress update API returned error: ${response.statusCode}, Body: ${response.body}");
      } else {
        _logger.d("Progress update successful.");
      }
    } catch (e) {
      _logger.w('Failed to send progress update.', e);
      /* Handled gracefully */
    }
  }

  void _playNextEpisode() {
    final currentIndex = widget.otherEpisodes.indexWhere(
        (ep) => int.tryParse(ep['id'] ?? '-1') == _currentEpisodeId);
    if (currentIndex != -1 && currentIndex < widget.otherEpisodes.length - 1) {
      _logger.i("Playing next episode in the playlist.");
      _playEpisode(widget.otherEpisodes[currentIndex + 1]);
    } else {
      _logger.i("Reached the end of the playlist.");
      if (mounted) _showInfoSnackbar("You've reached the end of the playlist.");
    }
  }

  void _playPreviousEpisode() {
    final currentIndex = widget.otherEpisodes.indexWhere(
        (ep) => int.tryParse(ep['id'] ?? '-1') == _currentEpisodeId);
    if (currentIndex > 0) {
      _logger.i("Playing previous episode in the playlist.");
      _playEpisode(widget.otherEpisodes[currentIndex - 1]);
    } else {
      _logger.i("Already at the first episode.");
      if (mounted) _showInfoSnackbar("You're at the first episode.");
    }
  }

  bool _hasNextEpisode() {
    final idx = widget.otherEpisodes
        .indexWhere((ep) => int.tryParse(ep['id'] ?? '-1') == _currentEpisodeId);
    return idx != -1 && idx < widget.otherEpisodes.length - 1;
  }

  bool _hasPreviousEpisode() {
    final idx = widget.otherEpisodes
        .indexWhere((ep) => int.tryParse(ep['id'] ?? '-1') == _currentEpisodeId);
    return idx > 0;
  }

  void _playEpisode(Map<String, String> episode) {
    final String? url = episode['url'] ?? episode['youtube_url'];
    final String? title = episode['title'] ?? episode['name'];
    final String? idStr = episode['id'];

    if (url == null || title == null || idStr == null) {
      _logger.w("Cannot play episode: data is incomplete. Data: $episode");
      if (mounted)
        _showErrorSnackbar("Cannot play episode: data is incomplete.");
      return;
    }
    final int? episodeId = int.tryParse(idStr);
    if (episodeId == null) {
      _logger.w("Cannot play episode: invalid episode ID format. ID: '$idStr'");
      if (mounted)
        _showErrorSnackbar("Cannot play episode: invalid episode ID format.");
      return;
    }
    final String? validatedUrl = _validateYoutubeUrl(url);
    if (validatedUrl == null) {
      _logger.w("Cannot play '$title': Invalid YouTube URL. URL: '$url'");
      if (mounted)
        _showErrorSnackbar("Cannot play '$title': Invalid YouTube URL.");
      return;
    }

    _logger.i(
        'Playing new episode: "$title" (ID: $episodeId), URL: $validatedUrl');
    if (mounted) {
      if (_isPlayerReady) _sendProgressUpdate();
      _progressUpdateTimer?.cancel();
      setState(() {
        _currentVideoUrl = validatedUrl;
        _currentEpisodeTitle = title;
        _currentEpisodeId = episodeId;
        _isPlayerReady = false;
        _isPlaying = false;
        _hasMarkedCompleted = false;
        _doubleTapConfigured = false;
        _currentThumbnailUrl = _youtubeThumbFromUrl(validatedUrl);
      });
    }

    final String? direct = _prefetchedUrlByEpisodeId[episodeId];
    if (direct != null && direct.isNotEmpty) {
      _podController.changeVideo(
        playVideoFrom: PlayVideoFrom.network(direct),
        playerConfig: PodPlayerConfig(
          autoPlay: true,
          isLooping: false,
          videoQualityPriority: _qualityPriority,
          wakelockEnabled: true,
        ),
      );
    } else {
      _podController.changeVideo(
        playVideoFrom: PlayVideoFrom.youtube(validatedUrl),
        playerConfig: PodPlayerConfig(
          autoPlay: true,
          isLooping: false,
          videoQualityPriority: _qualityPriority,
          wakelockEnabled: true,
        ),
      );
    }
    FocusScope.of(context).unfocus();

    // Prefetch the next one for smoother transition
    _prefetchNextEpisode();
  }

  void _showErrorSnackbar(String message) {
    if (!mounted || _isDisposing) return;
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
    if (!mounted || _isDisposing) return;
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

  Future<void> _applyFullScreenUi(bool isFullScreen) async {
    if (isFullScreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp]);
    }
  }

  Future<PlayVideoFrom> _resolveInitialSource(String url) async {
    try {
      final list = await PodPlayerController.getYoutubeUrls(url);
      if (list != null && list.isNotEmpty) {
        String? chosen;
        for (final q in _qualityPriority) {
          for (final item in list) {
            if (item.quality == q) {
              chosen = item.url;
              break;
            }
          }
          if (chosen != null) break;
        }
        chosen ??= list.first.url;
        _prefetchedUrlByEpisodeId[_currentEpisodeId] = chosen;
        return PlayVideoFrom.network(chosen);
      }
    } catch (e) {
      _logger.d('Initial resolve failed, fallback to YouTube: $e');
    }
    return PlayVideoFrom.youtube(url);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _logger.d("App lifecycle state changed: ${state.name}");
    if (!mounted) return;
    if (state == AppLifecycleState.paused &&
        _isPlayerReady &&
        _podController.isVideoPlaying) {
      _logger.i("App paused, pausing video and sending progress update.");
      _podController.pause();
      _sendProgressUpdate();
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // This helps detect when the system changes orientation
    // and prevents the fullscreen toggle loop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final newIsFullScreen = _podController.isFullScreen;
        if (newIsFullScreen != _isFullScreen) {
          setState(() {
            _isFullScreen = newIsFullScreen;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _logger.i('Disposing YouTubePlayerPage.');
    _isDisposing = true;
    WidgetsBinding.instance.removeObserver(this);
    _progressUpdateTimer?.cancel();

    // Always exit fullscreen on dispose to avoid state issues
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }

    if (_isPlayerReady &&
        (_podController.currentVideoPosition > Duration.zero)) {
      // Avoid showing UI during dispose; just attempt a silent progress update.
      _sendProgressUpdate(showErrors: false);
    }

    _podController.removeListener(_podListener);
    _podController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _updateThemeColors();

    return Scaffold(
      appBar: _isFullScreen
          ? null
          : AppBar(
              title: Text(
                _currentEpisodeTitle,
                style: const TextStyle(
                  color: Color.fromARGB(255, 0, 0, 0),
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
        top: !_isFullScreen,
        bottom: !_isFullScreen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: !_controllerReady
                  ? _buildInitialPlaceholder()
                  : Stack(
                      children: [
                        PodVideoPlayer(
                          controller: _podController,
                          videoThumbnail: _currentThumbnailUrl == null
                              ? null
                              : DecorationImage(
                                  image: NetworkImage(_currentThumbnailUrl!),
                                  fit: BoxFit.cover,
                                ),
                          podPlayerLabels: const PodPlayerLabels(
                            play: 'Play',
                            pause: 'Pause',
                            mute: 'Mute',
                            unmute: 'Unmute',
                            fullscreen: 'Fullscreen',
                            exitFullScreen: 'Exit fullscreen',
                            settings: 'Settings',
                            quality: 'Quality',
                            playbackSpeed: 'Speed',
                          ),
                          podProgressBarConfig: PodProgressBarConfig(
                            playingBarColor: _primaryColor,
                            circleHandlerColor: _primaryColor.withOpacity(0.9),
                          ),
                        ),
                        if (_hasPreviousEpisode()) _buildNavButton(isNext: false),
                        if (_hasNextEpisode()) _buildNavButton(isNext: true),
                      ],
                    ),
            ),
            if (!_isFullScreen)
              Expanded(
                child: Container(
                  color: _belowPlayerBgColor,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildVideoInfo(),
                        _buildPlaylist(),
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

  Widget _buildInitialPlaceholder() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_currentThumbnailUrl != null)
          Image.network(_currentThumbnailUrl!, fit: BoxFit.cover),
        Container(color: Colors.black.withOpacity(0.35)),
        const Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      ],
    );
  }

  Widget _buildNavButton({required bool isNext}) {
    final alignment = isNext ? Alignment.centerRight : Alignment.centerLeft;
    final icon = isNext ? Icons.skip_next_rounded : Icons.skip_previous_rounded;
    final onTap = isNext ? _playNextEpisode : _playPreviousEpisode;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: Material(
          color: Colors.black.withOpacity(0.35),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylist() {
    final playlistItems = widget.otherEpisodes;
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
              _buildPlaylistItem(playlistItems[index], index),
        ),
      ],
    );
  }

  Widget _buildPlaylistItem(Map<String, String> episode, int index) {
    final int? episodeId = int.tryParse(episode['id'] ?? '');
    final bool isCurrent = episodeId != null && episodeId == _currentEpisodeId;
    final String thumbnailUrl = episode['thumbnail_url'] ??
        episode['thumbnail'] ??
        episode['image'] ??
        '';
    final String title =
        episode['title'] ?? episode['name'] ?? 'Untitled Episode';
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
        onTap: isCurrent ? null : () => _playEpisode(episode),
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
                  if (isCurrent && _isPlayerReady && _isPlaying)
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

  String? _validateYoutubeUrl(String url) {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    final host = uri.host.toLowerCase();
    if (!host.contains('youtube.com') && !host.contains('youtu.be')) {
      return null;
    }
    return trimmed;
  }

  String? _youtubeThumbFromUrl(String url) {
    final id = _extractYoutubeId(url);
    if (id == null) return null;
    return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }

  String? _extractYoutubeId(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      if (host.contains('youtu.be')) {
        final segs = uri.pathSegments;
        if (segs.isNotEmpty) return segs.first;
      }
      if (host.contains('youtube.com')) {
        final v = uri.queryParameters['v'];
        if (v != null && v.isNotEmpty) return v;
        // Shorts or embed
        final segs = uri.pathSegments;
        if (segs.contains('shorts') && segs.length >= 2) {
          return segs[1];
        }
        if (segs.contains('embed') && segs.length >= 2) {
          return segs[1];
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _prefetchNextEpisode() async {
    final idx = widget.otherEpisodes.indexWhere(
        (ep) => int.tryParse(ep['id'] ?? '-1') == _currentEpisodeId);
    if (idx == -1 || idx >= widget.otherEpisodes.length - 1) return;
    final next = widget.otherEpisodes[idx + 1];
    final idStr = next['id'];
    final String? url = next['url'] ?? next['youtube_url'];
    final int? nextId = int.tryParse(idStr ?? '');
    if (nextId == null || url == null) return;
    if (_prefetchedForEpisodeId == nextId) return; // already prefetched
    if (_prefetchedUrlByEpisodeId.containsKey(nextId)) return;
    final valid = _validateYoutubeUrl(url);
    if (valid == null) return;
    try {
      final list = await PodPlayerController.getYoutubeUrls(valid);
      if (list == null || list.isEmpty) return;
      // pick best based on our priority order
      String? chosen;
      for (final q in _qualityPriority) {
        for (final item in list) {
          if (item.quality == q) {
            chosen = item.url;
            break;
          }
        }
        if (chosen != null) break;
      }
      chosen ??= list.first.url;
      _prefetchedUrlByEpisodeId[nextId] = chosen;
      _prefetchedForEpisodeId = nextId;
      _logger.d('Prefetched next episode direct URL at quality: ' +
          (list.first.quality.toString()));
    } catch (e) {
      _logger.d('Prefetch failed: $e');
    }
  }

  bool _canShowUI() {
    // Keep a lightweight check that avoids ancestor lookups on deactivated widgets.
    return mounted && !_isDisposing;
  }
}
