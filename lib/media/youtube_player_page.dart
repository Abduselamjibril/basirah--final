// lib/youtube_player_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../theme_provider.dart'; // Adjust path if necessary

// --- Screen Recording Prevention Imports ---
import 'dart:io' show Platform;
import '../screen_capture_blocker.dart'; // Adjust path if necessary

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
  late YoutubePlayerController _ytController;
  late String _currentVideoId;
  late String _currentEpisodeTitle;
  late int _currentEpisodeId;

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

  // --- Screen Recording State ---
  bool _isIOSScreenRecording = false;
  StreamSubscription<bool>? _iosScreenRecordingSubscription;
  bool _hasShownRecordingDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _currentEpisodeId = widget.initialEpisodeId;
    _currentEpisodeTitle = widget.initialEpisodeTitle;
    final initialVideoId =
        YoutubePlayer.convertUrlToId(widget.initialYoutubeUrl);

    if (initialVideoId == null) {
      _currentVideoId = 'dQw4w9WgXcQ'; // Fallback video ID
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleInvalidUrl("Invalid initial YouTube URL provided.");
      });
    } else {
      _currentVideoId = initialVideoId;
    }

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

    if (Platform.isIOS) {
      ScreenCaptureBlocker.isScreenBeingRecorded().then((isRecording) {
        if (mounted) {
          setState(() => _isIOSScreenRecording = isRecording);
          if (isRecording) _handleIOSScreenRecordingChange(true);
        }
      });
      _iosScreenRecordingSubscription = ScreenCaptureBlocker
          .screenRecordingStatusStream
          .listen(_handleIOSScreenRecordingChange, onError: (error) {
        print(
            "[YouTubePlayerPage] Error listening to screen recording stream: $error");
        if (mounted) setState(() => _isIOSScreenRecording = false);
      });
    }
  }

  // --- All original logic methods (_handleIOSScreenRecordingChange, _playerListener, _sendProgressUpdate, etc.) remain unchanged ---
  // --- They are included below for completeness without modification to their logic ---

  void _handleIOSScreenRecordingChange(bool isRecording) {
    if (!mounted) return;

    bool oldStatus = _isIOSScreenRecording;
    setState(() => _isIOSScreenRecording = isRecording);

    if (isRecording) {
      print(
          "[YouTubePlayerPage] iOS screen recording detected! Pausing video.");
      if (_ytController.value.playerState == PlayerState.playing) {
        _ytController.pause();
      }
      _showScreenRecordingWarningDialog();
    } else {
      if (oldStatus == true && isRecording == false) {
        print("[YouTubePlayerPage] iOS screen recording stopped.");
        if (_ytController.value.isReady && !_isPlayerReady) {
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
                setState(() => _hasShownRecordingDialog = false);
                ScreenCaptureBlocker.isScreenBeingRecorded()
                    .then((isStillRecording) {
                  if (mounted) {
                    if (_isIOSScreenRecording && !isStillRecording) {
                      _handleIOSScreenRecordingChange(false);
                    } else {
                      setState(() {
                        _isIOSScreenRecording = isStillRecording;
                      });
                    }
                  }
                });
              },
            ),
          ],
        );
      },
    );
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
      // *** MODIFICATION: Consistent AppBar colors with VideoPlayerPage ***
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

  void _playerListener() {
    if (!mounted) return;

    if (Platform.isIOS &&
        _isIOSScreenRecording &&
        _ytController.value.playerState == PlayerState.playing) {
      _ytController.pause();
      _showScreenRecordingWarningDialog();
      return;
    }

    final currentControllerState = _ytController.value.playerState;
    final bool wasPlayerLogicReady = _isPlayerReady;

    if (_ytController.value.isReady &&
        !(Platform.isIOS && _isIOSScreenRecording)) {
      if (!_isPlayerReady) {
        if (mounted) setState(() => _isPlayerReady = true);
      }
    } else {
      if (_isPlayerReady) {
        if (mounted) setState(() => _isPlayerReady = false);
      }
    }

    if (_isPlayerReady && !wasPlayerLogicReady) {
      _updateEpisodeProgress(_currentEpisodeId);
      if (_ytController.value.playerState == PlayerState.playing) {
        _startPeriodicProgressUpdates();
      }
    }

    if (_isPlayerReady && currentControllerState != _playerState) {
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
        if (!(Platform.isIOS && _isIOSScreenRecording)) {
          _playNextEpisode();
        }
      }
    }

    if (_ytController.value.errorCode != 0) {
      debugPrint(
          '[YouTubePlayerPage] Youtube Player Error Code: ${_ytController.value.errorCode}');
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
        _ytController.value.playerState == PlayerState.playing) {
      _progressUpdateTimer =
          Timer.periodic(const Duration(seconds: 15), (timer) {
        if (mounted && _ytController.value.playerState == PlayerState.playing) {
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
    if (!_isPlayerReady && !isCompleted) return;
    if (Platform.isIOS && _isIOSScreenRecording && !isCompleted) return;

    final phoneNumber = await _getPhoneNumber();
    if (phoneNumber == null) return;

    final currentPositionSeconds = _ytController.value.position.inSeconds;
    final totalDurationSeconds = _ytController.metadata.duration.inSeconds;

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
    final currentIndex = widget.otherEpisodes.indexWhere(
        (ep) => int.tryParse(ep['id'] ?? '-1') == _currentEpisodeId);
    if (currentIndex != -1 && currentIndex < widget.otherEpisodes.length - 1) {
      _playEpisode(widget.otherEpisodes[currentIndex + 1]);
    } else {
      if (mounted) _showInfoSnackbar("You've reached the end of the playlist.");
    }
  }

  void _playEpisode(Map<String, String> episode) {
    if (Platform.isIOS && _isIOSScreenRecording) {
      _showScreenRecordingWarningDialog();
      return;
    }
    final String? url = episode['url'] ?? episode['youtube_url'];
    final String? title = episode['title'] ?? episode['name'];
    final String? idStr = episode['id'];

    if (url == null || title == null || idStr == null) {
      if (mounted)
        _showErrorSnackbar("Cannot play episode: data is incomplete.");
      return;
    }
    final int? episodeId = int.tryParse(idStr);
    if (episodeId == null) {
      if (mounted)
        _showErrorSnackbar("Cannot play episode: invalid episode ID format.");
      return;
    }
    final String? videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId == null) {
      if (mounted)
        _showErrorSnackbar("Cannot play '$title': Invalid YouTube URL.");
      return;
    }

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
    if (Platform.isIOS && _isIOSScreenRecording) {
      if (_ytController.value.isFullScreen)
        _ytController.toggleFullScreenMode();
      _showScreenRecordingWarningDialog();
      return;
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    if (mounted) setState(() {});
  }

  void _exitFullScreen() {
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
    if (!mounted) return;
    if (state == AppLifecycleState.paused &&
        _isPlayerReady &&
        _ytController.value.playerState == PlayerState.playing) {
      _ytController.pause();
      if (!(Platform.isIOS && _isIOSScreenRecording)) _sendProgressUpdate();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _iosScreenRecordingSubscription?.cancel();
    _progressUpdateTimer?.cancel();
    if (mounted &&
        _isPlayerReady &&
        (_ytController.value.position > Duration.zero)) {
      if (!(Platform.isIOS && _isIOSScreenRecording)) _sendProgressUpdate();
    }
    if (_ytController.value.isFullScreen) _exitFullScreen();
    _ytController.removeListener(_playerListener);
    _ytController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _updateThemeColors();
    final bool hideUIForRecording = Platform.isIOS && _isIOSScreenRecording;
    final bool enablePlaylistTapInteraction = !hideUIForRecording;

    // Use a different color for the player's top bar back button
    // It's on a black background, so white is better.
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
          if (mounted && hideUIForRecording) {
            _ytController.pause();
            _showScreenRecordingWarningDialog();
          } else if (mounted &&
              _ytController.value.isReady &&
              !_isPlayerReady) {
            _playerListener();
          }
        },
        topActions: <Widget>[
          const SizedBox(width: 8.0),
          if (!_ytController.value.isFullScreen &&
              Navigator.canPop(context) &&
              !hideUIForRecording)
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
          appBar: _ytController.value.isFullScreen || hideUIForRecording
              ? null
              : AppBar(
                  // *** MODIFICATION: Title color changed and logo removed ***
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
                  // actions list is removed
                ),
          backgroundColor: _scaffoldBgColor,
          body: SafeArea(
            top: !_ytController.value.isFullScreen,
            bottom: !_ytController.value.isFullScreen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: hideUIForRecording
                      ? _buildScreenRecordingOverlay()
                      : playerWidgetFromBuilder,
                ),
                if (!_ytController.value.isFullScreen)
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
      },
    );
  }

  // --- UI ENHANCEMENT: Improved Screen Recording Overlay ---
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

  // --- UI ENHANCEMENT: Improved Video Info Section ---
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

  // --- UI ENHANCEMENT: Improved Playlist Section ---
  Widget _buildPlaylist(bool enableTap) {
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
              _buildPlaylistItem(playlistItems[index], index, enableTap),
        ),
      ],
    );
  }

  // --- UI ENHANCEMENT: Completely Redesigned Playlist Item ---
  Widget _buildPlaylistItem(
      Map<String, String> episode, int index, bool enableTap) {
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
                      _playerState == PlayerState.playing &&
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
