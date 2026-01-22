import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/audio/audio_handler.dart';
import '../media/audio_player_page.dart';

class MiniAudioPlayerBar extends StatefulWidget {
  const MiniAudioPlayerBar({super.key});

  @override
  State<MiniAudioPlayerBar> createState() => _MiniAudioPlayerBarState();
}

class _MiniAudioPlayerBarState extends State<MiniAudioPlayerBar> {
  BasirahAudioHandler? _handler;
  AudioPlayer? _player;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final handler = await BasirahAudioHandler.init();
      if (!mounted) return;
      setState(() {
        _handler = handler;
        _player = handler.player;
        _ready = true;
      });
    } catch (_) {
      // Ignore init errors; keep bar hidden.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _handler == null || _player == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<MediaItem?>(
      stream: _handler!.mediaItem,
      builder: (context, mediaSnapshot) {
        final item = mediaSnapshot.data;
        if (item == null) return const SizedBox.shrink();
        return StreamBuilder<PlaybackState>(
          stream: _handler!.playbackState,
          builder: (context, stateSnapshot) {
            final state = stateSnapshot.data;
            final processing = state?.processingState;
            final completed = processing == AudioProcessingState.completed;
            if (completed) return const SizedBox.shrink();
            final playing = state?.playing ?? false;

            return Material(
              elevation: 6,
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                top: false,
                child: InkWell(
                  onTap: () {
                    final extras = item.extras ?? const {};
                    final episodeId = (extras['episodeId'] as int?) ?? 0;
                    final contentId = (extras['contentId'] as int?) ?? 0;
                    final contentType = (extras['contentType'] as String?) ?? 'audio';
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AudioPlayerPage(
                          audioUrl: item.id,
                          episodeId: episodeId,
                          contentId: contentId,
                          contentType: contentType,
                          imageUrl: item.artUri?.toString(),
                          episodeTitle: item.title,
                          storyTitle: item.album,
                          episodes: null,
                          currentEpisodeId: episodeId,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            if (item.artUri != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: CachedNetworkImage(
                                  imageUrl: item.artUri.toString(),
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  fadeInDuration: Duration.zero,
                                  fadeOutDuration: Duration.zero,
                                  placeholder: (_, __) => Container(
                                    width: 44,
                                    height: 44,
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.music_note, size: 20),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    width: 44,
                                    height: 44,
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.music_note, size: 20),
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.music_note, size: 20),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                  if (item.album != null)
                                    Text(
                                      item.album!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                              onPressed: () {
                                if (playing) {
                                  _handler!.pause();
                                } else {
                                  _handler!.play();
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () async {
                                try {
                                  await _handler!.stopAndClear();
                                } catch (_) {}
                              },
                            ),
                          ],
                        ),
                      ),
                      _ProgressBar(player: _player!),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final AudioPlayer player;
  const _ProgressBar({required this.player});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final total = player.duration ?? Duration.zero;
        final value = total.inMilliseconds == 0
            ? 0.0
            : position.inMilliseconds / total.inMilliseconds;
        return LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: 2,
        );
      },
    );
  }
}
