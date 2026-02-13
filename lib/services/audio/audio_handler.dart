import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class BasirahAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  BasirahAudioHandler._internal() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.durationStream.listen((duration) {
      final currentItem = mediaItem.value;
      if (currentItem != null && duration != null) {
        mediaItem.add(currentItem.copyWith(duration: duration));
      }
    });
  }

  static BasirahAudioHandler? _instance;

  static Future<BasirahAudioHandler> init() async {
    if (_instance != null) return _instance!;
    _instance = await AudioService.init(
      builder: () => BasirahAudioHandler._internal(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'basirah_audio_channel',
        androidNotificationChannelName: 'Basirah Audio',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    return _instance!;
  }

  AudioPlayer get player => _player;

  Future<void> loadAndPlay(MediaItem item) async {
    mediaItem.add(item);
    await _player.setUrl(item.id);
    await play();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  Future<void> stopAndClear() async {
    await stop();
    // Clear current media item so mini player hides.
    mediaItem.add(null);
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [1, 3],
      processingState: _transformProcessingState(event.processingState),
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  AudioProcessingState _transformProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }
}
