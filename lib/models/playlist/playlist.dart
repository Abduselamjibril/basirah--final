import 'package:basirahtv/models/playlist/playlist_item.dart';

class Playlist {
  final int id;
  final String name;
  final DateTime createdAt;
  final int? itemsCount;
  final List<PlaylistItem>? items;

  Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    this.itemsCount,
    this.items,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    // This helper function for the nullable itemsCount is already correct.
    int? parseItemCount(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) {
        return int.tryParse(value); // Will return null if parsing fails
      }
      return null;
    }

    // --- FIX APPLIED HERE ---
    // A robust helper for the non-nullable 'id' field.
    int _parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }
    // --- END FIX ---

    return Playlist(
      // Use the safe parser for the main playlist 'id'.
      id: _parseInt(json['id']),
      name: json['name'] ?? 'Unnamed Playlist',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      itemsCount: parseItemCount(json['items_count']),
      items: (json['items'] as List?)
          ?.map((itemJson) => PlaylistItem.fromJson(itemJson))
          .toList(),
    );
  }
}
