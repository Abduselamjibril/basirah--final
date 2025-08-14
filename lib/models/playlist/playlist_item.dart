import 'package:basirah/models/playlist/generic_episode.dart';

class PlaylistItem {
  final int itemId;
  final int order;
  final GenericEpisode episode;

  PlaylistItem({
    required this.itemId,
    required this.order,
    required this.episode,
  });

  factory PlaylistItem.fromJson(Map<String, dynamic> json) {
    // --- FIX APPLIED HERE ---

    // A robust helper function to safely parse a value into an integer.
    // It can handle nulls, integers, and strings without crashing.
    int _parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0; // Fallback for other unexpected types
    }

    // --- END FIX ---

    // This logic for handling the nested episode is still correct.
    final episodeData = json['episode'] as Map<String, dynamic>?;
    GenericEpisode parsedEpisode;
    if (episodeData == null) {
      parsedEpisode =
          GenericEpisode.deleted(title: "Content no longer available");
    } else {
      parsedEpisode = GenericEpisode.fromJson(episodeData);
    }

    return PlaylistItem(
      // Use the safe parser for 'item_id' and 'order'.
      itemId: _parseInt(json['item_id']),
      order: _parseInt(json['order']),
      episode: parsedEpisode,
    );
  }
}
