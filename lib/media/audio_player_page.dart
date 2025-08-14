// lib/audio_player_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart'; // Adjust path if necessary

// --- Screen Recording Prevention Imports ---
import 'dart:io' show Platform;
import '../screen_capture_blocker.dart'; // Adjust path if necessary

// Define the Base URL
const String _apiBaseUrl = "https://admin.basirahtv.com";

// --- THEME OVERRIDE: Custom primary color for the player ---
const Color _playerPrimaryColor = Color(0xFF009B77);

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  PositionData(this.position, this.bufferedPosition, this.duration);
}

class AudioPlayerPage extends StatefulWidget {
  final String audioUrl;
  final int episodeId;
  final int contentId;
  final String contentType;
  final String? imageUrl;
  final String? episodeTitle;
  final String? storyTitle;
  final List<dynamic>? episodes;
  final int currentEpisodeId;

  const AudioPlayerPage({
    required this.audioUrl,
    required this.episodeId,
    required this.contentId,
    required this.contentType,
    this.imageUrl,
    this.episodeTitle,
    this.storyTitle,
    this.episodes,
    required this.currentEpisodeId,
    Key? key,
  }) : super(key: key);

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage>
    with WidgetsBindingObserver {
  late final AudioPlayer _audioPlayer;
  final _playbackSpeedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  bool _isLoading = true;
  bool _isBuffering = false;
  bool _hasError = false;
  Timer? _progressUpdateTimer;
  bool _isCompleted = false;

  bool _isIOSScreenRecording = false;
  StreamSubscription<bool>? _iosScreenRecordingSubscription;
  bool _hasShownRecordingDialog = false;

  // --- initState, handlers, and core logic remain the same ---
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioPlayer = AudioPlayer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initAudioPlayer();
      }
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
            "[AudioPlayerPage] Error listening to screen recording stream: $error");
        if (mounted) setState(() => _isIOSScreenRecording = false);
      });
    }
  }

  void _handleIOSScreenRecordingChange(bool isRecording) {
    if (!mounted) return;
    bool oldStatus = _isIOSScreenRecording;
    setState(() => _isIOSScreenRecording = isRecording);

    if (isRecording) {
      print("[AudioPlayerPage] iOS screen recording detected! Pausing audio.");
      if (_audioPlayer.playing) _audioPlayer.pause();
      _showScreenRecordingWarningDialog();
    } else {
      if (oldStatus == true && isRecording == false) {
        print("[AudioPlayerPage] iOS screen recording stopped.");
        if (!_audioPlayer.playing &&
            !_isLoading &&
            _audioPlayer.processingState != ProcessingState.ready &&
            !_hasError) {
          print(
              "[AudioPlayerPage] Attempting to initialize audio after screen recording stopped.");
          _initAudioPlayer();
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
              "To protect our content, audio playback is disabled while screen recording is active. Please stop recording to continue.",
              style: TextStyle(
                  color: isNightMode ? Colors.white70 : Colors.black54)),
          actions: <Widget>[
            TextButton(
              child: const Text("OK",
                  style: TextStyle(color: _playerPrimaryColor)),
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

  Future<void> _initAudioPlayer() async {
    if (!mounted) return;
    if (Platform.isIOS && _isIOSScreenRecording) {
      print(
          "[AudioPlayerPage] iOS screen capture active, delaying audio initialization.");
      setState(() => _isLoading = false);
      _showScreenRecordingWarningDialog();
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _isCompleted = false;
    });

    try {
      _audioPlayer.playerStateStream.listen((state) {
        if (!mounted) return;
        final bool currentlyBuffering =
            state.processingState == ProcessingState.buffering;
        if (currentlyBuffering != _isBuffering) {
          setState(() => _isBuffering = currentlyBuffering);
        }

        if (!_isCompleted &&
            state.processingState == ProcessingState.completed) {
          print(
              "[AudioPlayerPage] Audio completed for episode ${widget.episodeId}");
          if (mounted) setState(() => _isCompleted = true);
          _sendProgressUpdate(isCompleted: true);
          _progressUpdateTimer?.cancel();
        }

        if (Platform.isIOS && _isIOSScreenRecording && state.playing) {
          _audioPlayer.pause();
          _showScreenRecordingWarningDialog();
          return;
        }

        if (state.playing) {
          if (!_isCompleted &&
              (_progressUpdateTimer == null ||
                  !_progressUpdateTimer!.isActive)) {
            _startPeriodicProgressUpdates();
          }
          if (_isCompleted) if (mounted) setState(() => _isCompleted = false);
        } else {
          _progressUpdateTimer?.cancel();
          if (state.processingState != ProcessingState.completed &&
              _audioPlayer.position > Duration.zero &&
              !_isCompleted) {
            if (!(Platform.isIOS && _isIOSScreenRecording)) {
              _sendProgressUpdate();
            }
          }
        }
      }, onError: (Object e, StackTrace stackTrace) {
        print('[AudioPlayerPage] Audio player stream error: $e');
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
          _showErrorSnackbar('Player stream error.');
        }
      });

      await _audioPlayer
          .setAudioSource(AudioSource.uri(Uri.parse(widget.audioUrl)));
      if (!(Platform.isIOS && _isIOSScreenRecording)) _audioPlayer.play();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      print("[AudioPlayerPage] Error initializing audio player: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        _showErrorSnackbar('Failed to load audio.');
      }
    }
  }

  void _startPeriodicProgressUpdates() {
    _progressUpdateTimer?.cancel();
    _progressUpdateTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted && _audioPlayer.playing && !_isCompleted) {
        if (!(Platform.isIOS && _isIOSScreenRecording)) _sendProgressUpdate();
      } else if (!mounted || !_audioPlayer.playing) {
        timer.cancel();
      }
    });
  }

  Future<void> _sendProgressUpdate({bool isCompleted = false}) async {
    if (!mounted || (_isCompleted && isCompleted == false)) return;
    if (Platform.isIOS && _isIOSScreenRecording && !isCompleted) return;

    final phoneNumber = await _getPhoneNumber();
    if (phoneNumber == null) return;
    final currentPositionSeconds = _audioPlayer.position.inSeconds;
    final totalDurationSeconds = _audioPlayer.duration?.inSeconds;

    final bool nearEnd = totalDurationSeconds != null &&
        (totalDurationSeconds - currentPositionSeconds) < 5;
    if (currentPositionSeconds <= 0 &&
        !isCompleted &&
        !nearEnd &&
        (totalDurationSeconds ?? 0) > 5) return;

    final body = json.encode({
      'phone_number': phoneNumber,
      'episode_id': widget.episodeId,
      'content_id': widget.contentId,
      'content_type': widget.contentType,
      'current_position_seconds': currentPositionSeconds,
      if (isCompleted) 'is_completed': true,
      if (totalDurationSeconds != null && totalDurationSeconds > 0)
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
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 && response.statusCode != 201) {
        print(
            '[AudioPlayerPage] Failed to update audio progress: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[AudioPlayerPage] Error sending audio progress update: $e');
    }
  }

  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
          _audioPlayer.positionStream,
          _audioPlayer.bufferedPositionStream,
          _audioPlayer.durationStream,
          (p, bp, d) => PositionData(p, bp, d ?? Duration.zero));

  Future<String?> _getPhoneNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('userPhoneNumber');
    } catch (e) {
      print("[AudioPlayerPage] Error getting phone number: $e");
      return null;
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final minutesPadded = minutes.toString().padLeft(2, '0');
    final secondsPadded = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return "${hours.toString().padLeft(2, '0')}:$minutesPadded:$secondsPadded";
    } else {
      return "$minutesPadded:$secondsPadded";
    }
  }

  void _showErrorSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isNightMode = themeProvider.isDarkMode;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text("Error loading audio",
          style: TextStyle(color: Colors.white)),
      backgroundColor: isError
          ? Colors.redAccent.shade700
          : (isNightMode
              ? Colors.grey.shade700
              : _playerPrimaryColor.withOpacity(0.9)),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: Duration(seconds: isError ? 4 : 2),
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;
    if (state == AppLifecycleState.paused && _audioPlayer.playing) {
      _audioPlayer.pause();
      if (!(Platform.isIOS && _isIOSScreenRecording)) _sendProgressUpdate();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _iosScreenRecordingSubscription?.cancel();
    _progressUpdateTimer?.cancel();
    if (mounted &&
        _audioPlayer.playing &&
        !_isCompleted &&
        _audioPlayer.position > Duration.zero) {
      if (!(Platform.isIOS && _isIOSScreenRecording)) _sendProgressUpdate();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!mounted) return const SizedBox.shrink();

    final themeProvider = Provider.of<ThemeProvider>(context);
    final isNightMode = themeProvider.isDarkMode;

    final Color primaryTextColor = isNightMode ? Colors.white : Colors.black87;
    final Color secondaryTextColor =
        isNightMode ? Colors.white70 : Colors.grey[700]!;
    final Color placeholderBgColor =
        isNightMode ? Colors.grey[800]! : Colors.grey[200]!;
    final Color placeholderIconColor =
        isNightMode ? Colors.grey[600]! : Colors.grey[500]!;

    final Color gradientStart = isNightMode
        ? const Color(0xFF001F3F)
        : _playerPrimaryColor.withOpacity(0.4);
    final Color gradientEnd =
        isNightMode ? const Color(0xFF1E2A3A) : Colors.white;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Now Playing',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.9)),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white.withOpacity(0.9)),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [gradientStart, gradientEnd],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.6],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                children: [
                  const Spacer(flex: 1),
                  _buildCoverArt(
                      placeholderBgColor, placeholderIconColor, isNightMode),
                  const SizedBox(height: 40),
                  _buildTrackInfo(primaryTextColor, secondaryTextColor),
                  const Spacer(flex: 2),
                  _buildPlayerControls(
                      isNightMode, !(Platform.isIOS && _isIOSScreenRecording)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (Platform.isIOS && _isIOSScreenRecording)
            _buildScreenRecordingOverlay(),
        ],
      ),
    );
  }

  Widget _buildCoverArt(
      Color placeholderBgColor, Color placeholderIconColor, bool isNightMode) {
    final screenHeight = MediaQuery.of(context).size.height;
    final double imageHeight = (screenHeight * 0.35).clamp(200.0, 320.0);

    return Hero(
      tag: 'audio_image_${widget.episodeId}',
      child: Container(
        height: imageHeight,
        width: imageHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isNightMode ? 0.6 : 0.25),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.0),
          child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
              ? Image.network(
                  widget.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: placeholderBgColor,
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              _playerPrimaryColor),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: placeholderBgColor,
                    child: Icon(Icons.music_note,
                        size: 80, color: placeholderIconColor),
                  ),
                )
              : Container(
                  color: placeholderBgColor,
                  child: Icon(Icons.music_note,
                      size: 80, color: placeholderIconColor),
                ),
        ),
      ),
    );
  }

  Widget _buildTrackInfo(Color primaryTextColor, Color secondaryTextColor) {
    return Column(
      children: [
        if (widget.storyTitle != null && widget.storyTitle!.isNotEmpty)
          Text(
            widget.storyTitle!,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: primaryTextColor,
                letterSpacing: 0.5),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 8),
        if (widget.episodeTitle != null &&
            widget.episodeTitle!.isNotEmpty &&
            widget.storyTitle != widget.episodeTitle)
          Text(
            widget.episodeTitle!,
            style: TextStyle(
                color: secondaryTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w400),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildScreenRecordingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.9),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.screen_share_outlined,
                  color: Colors.yellow.shade700, size: 60),
              const SizedBox(height: 20),
              const Text("Screen Recording Active",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              const Text(
                  "Audio playback is disabled to protect content. Please stop screen recording to continue.",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerControls(bool isNightMode, bool enableControls) {
    final Color primaryTextColor = isNightMode ? Colors.white : Colors.black87;
    final Color secondaryTextColor =
        isNightMode ? Colors.white70 : Colors.grey[700]!;
    final Color iconColor = isNightMode ? Colors.white : Colors.black87;
    final Color tertiaryTextColor =
        isNightMode ? Colors.white60 : Colors.grey[600]!;
    final Color sliderInactiveColor =
        isNightMode ? Colors.white.withOpacity(0.2) : Colors.grey[300]!;

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text('Failed to load audio',
                style: TextStyle(fontSize: 18, color: Colors.redAccent)),
            const SizedBox(height: 8),
            Text('Please check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: secondaryTextColor)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
                icon: const Icon(Icons.refresh, color: Colors.white),
                label:
                    const Text('Retry', style: TextStyle(color: Colors.white)),
                onPressed: enableControls ? _initAudioPlayer : null,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _playerPrimaryColor))
          ],
        ),
      );
    }
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_playerPrimaryColor)),
            const SizedBox(height: 20),
            Text('Loading audio...',
                style: TextStyle(fontSize: 16, color: primaryTextColor)),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StreamBuilder<PositionData>(
          stream: _positionDataStream,
          builder: (context, snapshot) {
            final positionData = snapshot.data;
            final position = positionData?.position ?? Duration.zero;
            final duration = positionData?.duration ?? Duration.zero;
            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _playerPrimaryColor,
                    inactiveTrackColor: sliderInactiveColor,
                    thumbColor: _playerPrimaryColor,
                    overlayColor: _playerPrimaryColor.withOpacity(0.2),
                    trackHeight: 5,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    min: 0,
                    max: duration.inMilliseconds.toDouble() > 0
                        ? duration.inMilliseconds.toDouble()
                        : 1.0,
                    value: position.inMilliseconds
                        .toDouble()
                        .clamp(0.0, duration.inMilliseconds.toDouble()),
                    onChanged: enableControls
                        ? (value) => _audioPlayer
                            .seek(Duration(milliseconds: value.toInt()))
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(position),
                          style: TextStyle(
                              fontSize: 12, color: tertiaryTextColor)),
                      Text(_formatDuration(duration),
                          style: TextStyle(
                              fontSize: 12, color: tertiaryTextColor)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10_rounded),
              iconSize: 36,
              color: iconColor.withOpacity(0.8),
              onPressed: enableControls
                  ? () => _audioPlayer
                      .seek(_audioPlayer.position - const Duration(seconds: 10))
                  : null,
            ),
            const SizedBox(width: 32),
            _buildPlayPauseButton(enableControls),
            const SizedBox(width: 32),
            IconButton(
              icon: const Icon(Icons.forward_10_rounded),
              iconSize: 36,
              color: iconColor.withOpacity(0.8),
              onPressed: enableControls
                  ? () => _audioPlayer
                      .seek(_audioPlayer.position + const Duration(seconds: 10))
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 30),
        _buildExtraControlsRow(isNightMode, enableControls),
      ],
    );
  }

  Widget _buildPlayPauseButton(bool enableControls) {
    return StreamBuilder<PlayerState>(
      stream: _audioPlayer.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final isPlaying = playerState?.playing ?? false;
        final processingState = playerState?.processingState;

        if (_isBuffering && processingState != ProcessingState.completed) {
          return Container(
            margin: const EdgeInsets.all(8),
            width: 72,
            height: 72,
            child: const CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(_playerPrimaryColor)),
          );
        }

        IconData icon;
        if (isPlaying) {
          icon = Icons.pause_circle_filled_rounded;
        } else if (processingState == ProcessingState.completed ||
            _isCompleted) {
          icon = Icons.replay_circle_filled_rounded;
        } else {
          icon = Icons.play_circle_filled_rounded;
        }

        return IconButton(
          iconSize: 80,
          icon: Icon(icon, color: _playerPrimaryColor),
          onPressed: enableControls
              ? () {
                  if (isPlaying) {
                    _audioPlayer.pause();
                  } else {
                    if (processingState == ProcessingState.completed ||
                        _isCompleted) {
                      _audioPlayer.seek(Duration.zero);
                    }
                    _audioPlayer.play();
                  }
                }
              : null,
        );
      },
    );
  }

  Widget _buildExtraControlsRow(bool isNightMode, bool enableControls) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        StreamBuilder<double>(
          stream: _audioPlayer.speedStream,
          builder: (context, snapshot) {
            final speed = snapshot.data ?? 1.0;
            String speedText = "${speed % 1 == 0 ? speed.toInt() : speed}x";
            return _buildControlButton(
                icon: Icons.speed_rounded,
                label: speedText,
                onPressed:
                    enableControls ? () => _showSpeedMenu(context) : null,
                isNightMode: isNightMode);
          },
        ),
        StreamBuilder<double>(
          stream: _audioPlayer.volumeStream,
          builder: (context, snapshot) {
            final volume = snapshot.data ?? 1.0;
            IconData volumeIcon;
            if (volume <= 0) {
              volumeIcon = Icons.volume_off_rounded;
            } else if (volume <= 0.5) {
              volumeIcon = Icons.volume_down_rounded;
            } else {
              volumeIcon = Icons.volume_up_rounded;
            }
            return _buildControlButton(
                icon: volumeIcon,
                label: 'Volume',
                onPressed:
                    enableControls ? () => _showVolumeSlider(context) : null,
                isNightMode: isNightMode);
          },
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isNightMode,
  }) {
    final Color buttonColor =
        isNightMode ? Colors.white70 : Colors.black.withOpacity(0.7);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, size: 24, color: buttonColor),
          onPressed: onPressed,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: buttonColor, fontSize: 12),
        ),
      ],
    );
  }

  void _showSpeedMenu(BuildContext context) {
    if (Platform.isIOS && _isIOSScreenRecording) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (builderContext) {
        final themeProvider = Provider.of<ThemeProvider>(builderContext);
        final isNightMode = themeProvider.isDarkMode;
        final Color sheetBgColor =
            isNightMode ? const Color(0xFF1E2A3A) : Colors.white;
        final Color titleColor = isNightMode ? Colors.white : Colors.black87;
        final Color chipSelectedColor = _playerPrimaryColor.withOpacity(0.2);
        final Color chipSelectedTextColor = _playerPrimaryColor;
        final Color chipDefaultTextColor =
            isNightMode ? Colors.white70 : Colors.black87;

        return Container(
          decoration: BoxDecoration(
            color: sheetBgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 16),
              Text(
                'Playback Speed',
                style: Theme.of(builderContext).textTheme.titleLarge?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<double>(
                  stream: _audioPlayer.speedStream,
                  builder: (context, snapshot) {
                    final currentSpeed = snapshot.data ?? 1.0;
                    return Wrap(
                      spacing: 12.0,
                      runSpacing: 8.0,
                      alignment: WrapAlignment.center,
                      children: _playbackSpeedOptions.map((speed) {
                        final isSelected = speed == currentSpeed;
                        return ChoiceChip(
                          label: Text('${speed}x'),
                          selected: isSelected,
                          onSelected: (_) {
                            _audioPlayer.setSpeed(speed);
                            Navigator.pop(builderContext);
                          },
                          backgroundColor: isNightMode
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                          selectedColor: chipSelectedColor,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? chipSelectedTextColor
                                : chipDefaultTextColor,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                  color: isSelected
                                      ? _playerPrimaryColor
                                      : Colors.transparent,
                                  width: 1.5)),
                        );
                      }).toList(),
                    );
                  }),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showVolumeSlider(BuildContext context) {
    if (Platform.isIOS && _isIOSScreenRecording) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (builderContext) {
        final themeProvider = Provider.of<ThemeProvider>(builderContext);
        final isNightMode = themeProvider.isDarkMode;
        final Color sheetBgColor =
            isNightMode ? const Color(0xFF1E2A3A) : Colors.white;
        final Color titleColor = isNightMode ? Colors.white : Colors.black87;
        final Color sliderInactiveColor =
            isNightMode ? Colors.grey[700]! : Colors.grey[300]!;

        return Container(
          decoration: BoxDecoration(
            color: sheetBgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 16),
              Text(
                'Volume',
                style: Theme.of(builderContext)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: titleColor, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              StreamBuilder<double>(
                stream: _audioPlayer.volumeStream,
                builder: (context, snapshot) {
                  final liveVolume = snapshot.data ?? 1.0;
                  return Slider(
                    value: liveVolume,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    label: '${(liveVolume * 100).round()}%',
                    activeColor: _playerPrimaryColor,
                    inactiveColor: sliderInactiveColor,
                    onChanged: (value) {
                      _audioPlayer.setVolume(value);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
