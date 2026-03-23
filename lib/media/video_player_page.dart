// lib/video_player_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme_provider.dart'; // Adjust path if necessary

// --- Screen Recording Prevention Imports ---
import 'dart:io' show Platform;
// Screen capture blocker functionality has been removed.

const String _apiBaseUrl = "https://admin.basirahtv.com";

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String episodeTitle;
  final List<Map<String, String>> otherEpisodes;
  final int episodeId;
  final int contentId;
  final String contentType;
  final List episodes;

  const VideoPlayerPage({
    required this.videoUrl,
    required this.episodeTitle,
    required this.otherEpisodes,
    required this.episodeId,
    required this.contentId,
    required this.contentType,
    required this.episodes,
    Key? key,
  }) : super(key: key);

  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage>
    with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _isFullScreen = false;
  bool _isVideoInitialized = false;
  bool _showControls = true;
  bool _isLoading = true;
  Timer? _hideControlsTimer;
  Timer? _progressUpdateTimer;
  bool _isCompleted = false;
  bool _isDraggingProgress = false;
  double _currentSliderValue = 0;

  String _currentVideoUrl = '';
  String _currentEpisodeTitle = '';
  int _currentEpisodeId = 0;

  Offset? _tapDownPosition;
  String? _seekAnimationType;
  bool _seekAnimationVisible = false;
  Timer? _seekAnimationTimer;

  // --- Theme related colors (Aligned with YouTube Player UI) ---
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
  late Color _appBarColor;
  late Color _iconColor;
  late Color _appBarIconColor;
  late Color _appBarTitleColor;
  late Color _primaryColor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _currentVideoUrl = widget.videoUrl;
    _currentEpisodeTitle = widget.episodeTitle;
    _currentEpisodeId = widget.episodeId;

    _controller = VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/placeholder.mp4'));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateThemeColors();
      _initializeVideoPlayer(_currentVideoUrl);
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
      _appBarColor = currentTheme.appBarTheme.backgroundColor ??
          (isNightMode ? const Color(0xFF1F1F1F) : _primaryColor);
      _appBarIconColor =
          currentTheme.appBarTheme.iconTheme?.color ?? Colors.white;
      _appBarTitleColor =
          currentTheme.appBarTheme.titleTextStyle?.color ?? Colors.white;
      _iconColor = Colors.white;
    });
  }

  Future<void> _initializeVideoPlayer(String url) async {
    setState(() {
      _isLoading = true;
      _isVideoInitialized = false;
      _isCompleted = false;
      _currentSliderValue = 0;
    });

    if (_controller.value.isInitialized) {
      await _controller.dispose();
    }
    _controller = VideoPlayerController.networkUrl(Uri.parse(url));

    try {
      await _controller.initialize();
      if (!mounted) return;

      setState(() {
        _isVideoInitialized = true;
        _isLoading = false;
      });
      _controller.play();
      _startPeriodicProgressUpdates();
      _controller.addListener(_videoPlayerListener);
      _showControls = true;
      _startHideControlsTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorSnackbar('Error loading video');
      print("[VideoPlayerPage] Error initializing video: $e");
    }
  }

  void _videoPlayerListener() {
    if (!mounted || !_controller.value.isInitialized) return;

    if (!_isDraggingProgress) {
      setState(() => _currentSliderValue =
          _controller.value.position.inMilliseconds.toDouble());
    }

    _checkVideoCompletion();

    if (_controller.value.isPlaying && _showControls && !_isDraggingProgress) {
      _startHideControlsTimer();
    } else if (!_controller.value.isPlaying && !_showControls) {
      if (mounted) setState(() => _showControls = true);
      _hideControlsTimer?.cancel();
    }
  }

  void _startPeriodicProgressUpdates() {
    _progressUpdateTimer?.cancel();
    _progressUpdateTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted && _isVideoInitialized && _controller.value.isPlaying) {
        _sendProgressUpdate();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendProgressUpdate({bool isCompleted = false}) async {
    if (!mounted || !_isVideoInitialized || (_isCompleted && isCompleted))
      return;

    final phoneNumber = await _getPhoneNumber();
    if (phoneNumber == null) return;
    final currentPositionSeconds = _controller.value.position.inSeconds;
    final totalDurationSeconds = _controller.value.duration.inSeconds;

    if (currentPositionSeconds <= 0 &&
        !isCompleted &&
        totalDurationSeconds > 0 &&
        (totalDurationSeconds - currentPositionSeconds) > 5) return;

    final body = json.encode({
      'phone_number': phoneNumber,
      'episode_id': _currentEpisodeId,
      'content_id': widget.contentId,
      'content_type': widget.contentType,
      'current_position_seconds': currentPositionSeconds,
      if (isCompleted) 'is_completed': true,
      if (_controller.value.isInitialized && totalDurationSeconds > 0)
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
      debugPrint('[VideoPlayerPage] Error sending progress update: $e');
    }
  }

  void _checkVideoCompletion() {
    if (mounted &&
        !_isCompleted &&
        _isVideoInitialized &&
        _controller.value.duration > Duration.zero &&
        _controller.value.position >= _controller.value.duration) {
      setState(() => _isCompleted = true);
      _sendProgressUpdate(isCompleted: true);
      _progressUpdateTimer?.cancel();
      _playNextEpisode();
    }
  }

  void _playNextEpisode() {
    final currentIndex = widget.otherEpisodes.indexWhere(
        (ep) => int.tryParse(ep['id'] ?? '-1') == _currentEpisodeId);
    if (currentIndex != -1 && currentIndex < widget.otherEpisodes.length - 1) {
      _changeEpisode(widget.otherEpisodes[currentIndex + 1]);
    } else {
      if (mounted) _showInfoSnackbar("You've reached the end of the playlist.");
    }
  }

  void _playPreviousEpisode() {
    final currentIndex = widget.otherEpisodes.indexWhere(
        (ep) => int.tryParse(ep['id'] ?? '-1') == _currentEpisodeId);
    if (currentIndex > 0) {
      _changeEpisode(widget.otherEpisodes[currentIndex - 1]);
    } else if (currentIndex == 0) {
      if (mounted)
        _showInfoSnackbar("This is the first episode in the playlist.");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressUpdateTimer?.cancel();
    _hideControlsTimer?.cancel();
    _seekAnimationTimer?.cancel();

    if (mounted &&
        _isVideoInitialized &&
        !_isCompleted &&
        _controller.value.position > Duration.zero) {
      _sendProgressUpdate();
    }

    _controller.removeListener(_videoPlayerListener);
    _controller.dispose();

    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;
    if (state == AppLifecycleState.paused &&
        _isVideoInitialized &&
        _controller.value.isPlaying) {
      _controller.pause();
      _sendProgressUpdate();
    }
  }

  void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _showControls = true);
        _startHideControlsTimer();
      }
    });
  }

  void _togglePlayPause() {
    if (!_isVideoInitialized) return;
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _progressUpdateTimer?.cancel();
        _sendProgressUpdate();
      } else {
        if (_isCompleted) {
          _controller.seekTo(Duration.zero);
          setState(() => _isCompleted = false);
        }
        _controller.play();
        _startPeriodicProgressUpdates();
      }
    });
    _startHideControlsTimer();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_controller.value.isPlaying && !_isDraggingProgress) {
      _hideControlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && _controller.value.isPlaying && !_isDraggingProgress) {
          setState(() => _showControls = false);
        }
      });
    } else {
      if (mounted && !_showControls && !_isDraggingProgress) {
        setState(() => _showControls = true);
      }
    }
  }

  void _toggleControlsVisibility() {
    if (!_isVideoInitialized) return;
    setState(() => _showControls = !_showControls);
    if (_showControls)
      _startHideControlsTimer();
    else
      _hideControlsTimer?.cancel();
  }

  void _changeEpisode(Map<String, String> newEpisodeData) {
    final String? newUrlPath = newEpisodeData['video_path'] ??
        newEpisodeData['video'] ??
        newEpisodeData['videoUrl'] ??
        newEpisodeData['url'];
    final String newTitle =
        newEpisodeData['title'] ?? newEpisodeData['name'] ?? 'Untitled Episode';
    final int? newEpisodeId = int.tryParse(newEpisodeData['id'] ?? '');

    if (newUrlPath == null || newUrlPath.isEmpty || newEpisodeId == null) {
      _showErrorSnackbar("Could not load selected episode: Data missing.");
      return;
    }
    final String newFullUrl = newUrlPath.startsWith('http')
        ? newUrlPath
        : '$_apiBaseUrl/storage/$newUrlPath';

    if (_isVideoInitialized && !_isCompleted) _sendProgressUpdate();
    _progressUpdateTimer?.cancel();
    _hideControlsTimer?.cancel();

    setState(() {
      _currentVideoUrl = newFullUrl;
      _currentEpisodeTitle = newTitle;
      _currentEpisodeId = newEpisodeId;
      _isLoading = true;
      _isVideoInitialized = false;
      _isCompleted = false;
      _currentSliderValue = 0;
      _showControls = true;
    });
    _initializeVideoPlayer(newFullUrl);
  }

  Future<String?> _getPhoneNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('userPhoneNumber');
    } catch (e) {
      debugPrint("[VideoPlayerPage] Error getting phone number: $e");
      return null;
    }
  }

  void _seekRelative(Duration offset) {
    if (!_isVideoInitialized) return;
    final currentPosition = _controller.value.position;
    var newPosition = currentPosition + offset;
    if (newPosition < Duration.zero) newPosition = Duration.zero;
    if (newPosition > _controller.value.duration)
      newPosition = _controller.value.duration;
    _controller.seekTo(newPosition);
    if (mounted)
      setState(
          () => _currentSliderValue = newPosition.inMilliseconds.toDouble());
    _startHideControlsTimer();
  }

  void _seekForward() => _seekRelative(const Duration(seconds: 10));
  void _seekBackward() => _seekRelative(const Duration(seconds: -10));

  void _showSeekAnimation(bool isForward) {
    if (!mounted) return;
    setState(() {
      _seekAnimationType = isForward ? 'forward' : 'backward';
      _seekAnimationVisible = true;
    });
    _seekAnimationTimer?.cancel();
    _seekAnimationTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _seekAnimationVisible = false);
    });
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
    ));
  }

  // --- UI BUILD METHODS START HERE ---

  @override
  Widget build(BuildContext context) {
    _updateThemeColors();

    return WillPopScope(
      onWillPop: () async {
        if (_isFullScreen) {
          _toggleFullScreen();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: _isFullScreen
            ? null
            : AppBar(
                title: Text(_currentEpisodeTitle,
                    style: TextStyle(color: _appBarTitleColor, fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                backgroundColor: _appBarColor,
                elevation: 1,
                shadowColor: Colors.black.withOpacity(0.2),
                iconTheme: IconThemeData(color: _appBarIconColor),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Center(
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 32,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.error_outline);
                        },
                      ),
                    ),
                  ),
                ],
              ),
        backgroundColor: _scaffoldBgColor,
        body: SafeArea(
          top: !_isFullScreen,
          bottom: !_isFullScreen,
          child: _isFullScreen
              ? _buildFullScreenContent()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildVideoPlayerArea(),
                    Expanded(
                      child: Container(
                        color: _belowPlayerBgColor,
                        child: CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(child: _buildVideoInfo()),
                            _buildPlaylistSliver(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFullScreenContent() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildVideoPlayerArea(),
    );
  }

  Widget _buildVideoPlayerArea() {
    Widget videoRenderWidget;
    if (_isVideoInitialized &&
        _controller.value.isInitialized &&
        _controller.value.size.width > 0) {
      if (_isFullScreen) {
        videoRenderWidget = SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.center,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
        );
      } else {
        videoRenderWidget = VideoPlayer(_controller);
      }
    } else {
      videoRenderWidget = Container(
        color: Colors.black,
        child: Center(
          child: _isLoading
              ? CircularProgressIndicator(color: _primaryColor)
              : Icon(Icons.error_outline,
                  color: _iconColor.withOpacity(0.7), size: 50),
        ),
      );
    }

    final List<Widget> stackChildren = [
      videoRenderWidget,
      GestureDetector(
        onTap: _toggleControlsVisibility,
        onDoubleTapDown: (details) {
          _tapDownPosition = details.localPosition;
        },
        onDoubleTap: () {
          if (_tapDownPosition == null || !_isVideoInitialized) return;
          final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox == null) return;
          final playerWidgetSize = renderBox.size;
          final double tapX = _tapDownPosition!.dx;

          if (tapX < playerWidgetSize.width / 3) {
            _seekBackward();
            _showSeekAnimation(false);
          } else if (tapX > playerWidgetSize.width * 2 / 3) {
            _seekForward();
            _showSeekAnimation(true);
          } else {
            _togglePlayPause();
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Container(color: Colors.transparent),
      ),
      if (_isVideoInitialized) _buildControlsOverlay(),
      if (_seekAnimationVisible && _seekAnimationType != null)
        Center(
          child: AnimatedOpacity(
            opacity: _seekAnimationVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                _seekAnimationType == 'forward'
                    ? Icons.fast_forward_rounded
                    : Icons.fast_rewind_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
    ];

    if (_isFullScreen) {
      return Stack(alignment: Alignment.center, children: stackChildren);
    } else {
      final double playerAspectRatio = _isVideoInitialized &&
              _controller.value.aspectRatio.isFinite &&
              _controller.value.aspectRatio > 0
          ? _controller.value.aspectRatio
          : 16 / 9;
      return AspectRatio(
        aspectRatio: playerAspectRatio,
        child: Container(
          color: Colors.black,
          child: Stack(alignment: Alignment.center, children: stackChildren),
        ),
      );
    }
  }

  Widget _buildControlsOverlay() {
    final bool shouldShowActualControls = _showControls ||
        !_controller.value.isPlaying ||
        _controller.value.isBuffering;

    return AnimatedOpacity(
      opacity: shouldShowActualControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: AbsorbPointer(
        absorbing: !shouldShowActualControls,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.5),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.5)
              ],
              stops: const [0.0, 0.25, 0.75, 1.0],
            ),
          ),
          child: Stack(
            children: [
              if (_isFullScreen) _buildTopControls(),
              _buildMiddleControls(),
              _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            children: [
              IconButton(
                icon:
                    Icon(Icons.arrow_back_ios_new, color: _iconColor, size: 20),
                onPressed: _toggleFullScreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentEpisodeTitle,
                  style: TextStyle(
                      color: _iconColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiddleControls() {
    final int currentIndex = widget.otherEpisodes.indexWhere(
        (ep) => int.tryParse(ep['id'] ?? '-1') == _currentEpisodeId);
    final bool canPlayPrevious = currentIndex > 0;
    final bool canPlayNext =
        currentIndex != -1 && currentIndex < widget.otherEpisodes.length - 1;
    final Color middleIconColor = _iconColor;
    final Color disabledIconColor = _iconColor.withOpacity(0.4);
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
              iconSize: 36,
              icon: Icon(Icons.skip_previous_rounded,
                  color: canPlayPrevious ? middleIconColor : disabledIconColor),
              onPressed: canPlayPrevious ? _playPreviousEpisode : null),
          IconButton(
              iconSize: 36,
              icon: Icon(Icons.replay_10_rounded, color: middleIconColor),
              onPressed: _seekBackward),
          IconButton(
              iconSize: 60,
              icon: Icon(
                  _controller.value.isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : (_isCompleted
                          ? Icons.replay_circle_filled_rounded
                          : Icons.play_circle_filled_rounded),
                  color: middleIconColor),
              onPressed: _togglePlayPause),
          IconButton(
              iconSize: 36,
              icon: Icon(Icons.forward_10_rounded, color: middleIconColor),
              onPressed: _seekForward),
          IconButton(
              iconSize: 36,
              icon: Icon(Icons.skip_next_rounded,
                  color: canPlayNext ? middleIconColor : disabledIconColor),
              onPressed: canPlayNext ? _playNextEpisode : null),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    final Color timeTextColor = _iconColor;
    final Color sliderActiveColor = _primaryColor;
    final Color sliderInactiveColor = _iconColor.withOpacity(0.3);
    final Color sliderThumbColor = _primaryColor;
    final Color sliderOverlayColor = _primaryColor.withOpacity(0.2);
    final Color fullscreenIconColor = _iconColor;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(
              left: 12.0, right: 12.0, top: 8.0, bottom: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(_formatDuration(_controller.value.position),
                  style: TextStyle(color: timeTextColor, fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 24,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: sliderActiveColor,
                      inactiveTrackColor: sliderInactiveColor,
                      thumbColor: sliderThumbColor,
                      overlayColor: sliderOverlayColor,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                          elevation: 1.0,
                          pressedElevation: 2.0),
                      trackHeight: 3.0,
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: _currentSliderValue.clamp(
                          0.0,
                          _controller.value.isInitialized &&
                                  _controller.value.duration.inMilliseconds > 0
                              ? _controller.value.duration.inMilliseconds
                                  .toDouble()
                              : 1.0),
                      min: 0,
                      max: _controller.value.isInitialized &&
                              _controller.value.duration.inMilliseconds > 0
                          ? _controller.value.duration.inMilliseconds.toDouble()
                          : 1.0,
                      onChangeStart: (value) {
                        setState(() => _isDraggingProgress = true);
                        _hideControlsTimer?.cancel();
                      },
                      onChangeEnd: (value) {
                        _controller
                            .seekTo(Duration(milliseconds: value.toInt()));
                        setState(() => _isDraggingProgress = false);
                        _startHideControlsTimer();
                      },
                      onChanged: (value) {
                        setState(() => _currentSliderValue = value);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(_formatDuration(_controller.value.duration),
                  style: TextStyle(color: timeTextColor, fontSize: 12)),
              const SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minHeight: 24, minWidth: 24),
                icon: Icon(
                    _isFullScreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    color: fullscreenIconColor,
                    size: 28),
                onPressed: _toggleFullScreen,
              ),
            ],
          ),
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

  Widget _buildPlaylistSliver() {
    final playlistItems = widget.otherEpisodes;
    if (playlistItems.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
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
            ],
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildPlaylistItem(playlistItems[index], index),
            childCount: playlistItems.length,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistItem(Map<String, String> episode, int index) {
    final int? episodeId = int.tryParse(episode['id'] ?? '');
    final bool isCurrent = episodeId != null && episodeId == _currentEpisodeId;
    final String thumbnailUrl = episode['thumbnail'] ?? episode['image'] ?? '';
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
        onTap: isCurrent ? null : () => _changeEpisode(episode),
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
                              child: Icon(Icons.ondemand_video_rounded)),
                    ),
                  ),
                  if (isCurrent &&
                      _isVideoInitialized &&
                      !_controller.value.isBuffering)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                          color: Colors.black.withOpacity(0.5),
                        ),
                        child: Icon(
                            _controller.value.isPlaying
                                ? Icons.graphic_eq_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28),
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
