// lib/youtube_player_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart'; // Import logger
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

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

  late YoutubePlayerController _ytController;
  late String _currentVideoId;
  late String _currentEpisodeTitle;
  late int _currentEpisodeId;
  bool _isFullScreen = false;

  bool _isPlayerReady = false;
  PlayerState _playerState = PlayerState.unknown;
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _currentEpisodeId = widget.initialEpisodeId;
    _currentEpisodeTitle = widget.initialEpisodeTitle;
    final initialVideoId =
        YoutubePlayer.convertUrlToId(widget.initialYoutubeUrl);

    if (initialVideoId == null) {
      _logger.e(
          "Invalid initial YouTube URL provided: ${widget.initialYoutubeUrl}");
      _currentVideoId = 'dQw4w9WgXcQ'; // Fallback video ID
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleInvalidUrl("Invalid initial YouTube URL provided.");
      });
    } else {
      _currentVideoId = initialVideoId;
    }

    _logger.i(
      'Initializing player for episode "${widget.initialEpisodeTitle}" (ID: $_currentEpisodeId) with Video ID: $_currentVideoId',
    );

    _ytController = YoutubePlayerController(
      initialVideoId: _currentVideoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: false,
        disableDragSeek: false,
        loop: false,
        forceHD: false,
        isLive: false,
      ),
    )..addListener(_playerListener);

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
      if (!mounted) return;
      _showErrorSnackbar(message);
      if (Navigator.canPop(context)) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
        });
      }
    });
  }

  void _playerListener() {
    if (!mounted) return;

    final currentControllerState = _ytController.value.playerState;
    final bool wasPlayerLogicReady = _isPlayerReady;

    if (_ytController.value.isReady) {
      if (!_isPlayerReady) {
        if (mounted) setState(() => _isPlayerReady = true);
      }
    } else {
      if (_isPlayerReady) {
        if (mounted) setState(() => _isPlayerReady = false);
      }
    }

    if (_isPlayerReady && !wasPlayerLogicReady) {
      _logger.i(
          "Player is now ready. State: ${_ytController.value.playerState.name}");
      _updateEpisodeProgress(_currentEpisodeId);
      if (_ytController.value.playerState == PlayerState.playing) {
        _startPeriodicProgressUpdates();
      }
    }

    if (_isPlayerReady && currentControllerState != _playerState) {
      _logger.d(
          "Player state changed from ${_playerState.name} to ${currentControllerState.name}");
      if (mounted) setState(() => _playerState = currentControllerState);
      if (_playerState == PlayerState.playing) {
        _startPeriodicProgressUpdates();
      } else {
        _progressUpdateTimer?.cancel();
        if (_playerState == PlayerState.paused &&
            _ytController.value.position > Duration.zero) {
          _sendProgressUpdate();
        }
      }
      if (_playerState == PlayerState.ended) {
        _sendProgressUpdate(isCompleted: true);
        _playNextEpisode();
      }
    }

    if (_ytController.value.errorCode != 0) {
      _logger.e('Youtube Player Error Code: ${_ytController.value.errorCode}');
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
      _logger.e("Error getting phone number from SharedPreferences", e);
      return null;
    }
  }

  void _startPeriodicProgressUpdates() {
    _progressUpdateTimer?.cancel();
    if (_isPlayerReady &&
        _ytController.value.playerState == PlayerState.playing) {
      _logger.d("Starting periodic progress updates every 15 seconds.");
      _progressUpdateTimer =
          Timer.periodic(const Duration(seconds: 15), (timer) {
        if (mounted && _ytController.value.playerState == PlayerState.playing) {
          _sendProgressUpdate();
        } else {
          _logger.d("Stopping periodic progress updates.");
          timer.cancel();
        }
      });
    }
  }

  // UPDATED METHOD STARTS HERE
  Future<void> _sendProgressUpdate({bool isCompleted = false}) async {
    if (!_isPlayerReady && !isCompleted) return;

    final phoneNumber = await _getPhoneNumber();
    if (phoneNumber == null) {
      _logger.w("Cannot send progress update: Phone number is null.");
      return;
    }

    // --- Add this: get token from SharedPreferences ---
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      _logger.w("Cannot send progress update: Auth token is null.");
      return;
    }
    // --------------------------------------------------

    final currentPositionSeconds = _ytController.value.position.inSeconds;
    final totalDurationSeconds = _ytController.metadata.duration.inSeconds;

    final bool nearEnd = totalDurationSeconds > 0 &&
        (totalDurationSeconds - currentPositionSeconds) < 5;
    if (currentPositionSeconds <= 0 &&
        !isCompleted &&
        !nearEnd &&
        totalDurationSeconds > 5) {
      _logger.d("Skipping progress update at the beginning of the video.");
      return;
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
                'Accept': 'application/json',
                'Authorization': 'Bearer $token', // <-- Add this line
              },
              body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        _logger.w("Authentication failed. User may need to log in again.");
        if (mounted) {
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
  // UPDATED METHOD ENDS HERE

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
    final String? videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId == null) {
      _logger.w("Cannot play '$title': Invalid YouTube URL. URL: '$url'");
      if (mounted)
        _showErrorSnackbar("Cannot play '$title': Invalid YouTube URL.");
      return;
    }

    _logger.i(
        'Playing new episode: "$title" (ID: $episodeId), Video ID: $videoId');
    if (mounted) {
      if (_isPlayerReady) _sendProgressUpdate();
      setState(() {
        _currentVideoId = videoId;
        _currentEpisodeTitle = title;
        _currentEpisodeId = episodeId;
        _isPlayerReady = false;
        _playerState = PlayerState.unknown;
      });
    }
    _ytController.load(videoId);
    FocusScope.of(context).unfocus();
  }

  void _enterFullScreen() {
    if (_isFullScreen) return; // Prevent re-entry

    _logger.d("Entering full screen.");
    _isFullScreen = true;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

    if (mounted) setState(() {});
  }

  void _exitFullScreen() {
    if (!_isFullScreen) return; // Prevent re-exit

    _logger.d("Exiting full screen.");
    _isFullScreen = false;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    if (mounted) setState(() {});
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    final Color errorBgColor = Colors.redAccent.shade700;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: errorBgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 30),
      dismissDirection: DismissDirection.horizontal,
    ));
  }

  void _showInfoSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
    _logger.d("App lifecycle state changed: ${state.name}");
    if (!mounted) return;
    if (state == AppLifecycleState.paused &&
        _isPlayerReady &&
        _ytController.value.playerState == PlayerState.playing) {
      _logger.i("App paused, pausing video and sending progress update.");
      _ytController.pause();
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
        final newIsFullScreen = _ytController.value.isFullScreen;
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
    WidgetsBinding.instance.removeObserver(this);
    _progressUpdateTimer?.cancel();

    // Always exit fullscreen on dispose to avoid state issues
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }

    if (mounted &&
        _isPlayerReady &&
        (_ytController.value.position > Duration.zero)) {
      _sendProgressUpdate();
    }

    _ytController.removeListener(_playerListener);
    _ytController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _updateThemeColors();
    final playerTopBarIconColor = Colors.white;

    return YoutubePlayerBuilder(
      onExitFullScreen: _exitFullScreen,
      onEnterFullScreen: _enterFullScreen,
      player: YoutubePlayer(
        controller: _ytController,
        showVideoProgressIndicator: true,
        progressIndicatorColor: _primaryColor,
        progressColors: ProgressBarColors(
          playedColor: _primaryColor,
          handleColor: _primaryColor.withOpacity(0.9),
        ),
        onReady: () {
          if (mounted && _ytController.value.isReady && !_isPlayerReady) {
            _playerListener();
          }
        },
        topActions: <Widget>[
          const SizedBox(width: 8.0),
          if (!_isFullScreen && Navigator.canPop(context))
            IconButton(
                icon: Icon(Icons.arrow_back_ios_new,
                    color: playerTopBarIconColor, size: 20.0),
                onPressed: () => Navigator.pop(context)),
          const Spacer(),
          const SizedBox(width: 8.0),
        ],
      ),
      builder: (context, playerWidgetFromBuilder) {
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
                  child: playerWidgetFromBuilder,
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
      },
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
                  if (isCurrent &&
                      _isPlayerReady &&
                      _playerState == PlayerState.playing)
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
