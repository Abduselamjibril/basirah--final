import 'package:logger/logger.dart';
import '../../models/content_type.dart';
import '../../models/playlist/playlist.dart';
import 'api_service.dart';

class PlaylistService {
  final ApiService _api;
  final _logger = Logger();
  PlaylistService(this._api);

  /// Fetches a list of the user's playlists, each with an item count.
  Future<List<Playlist>> fetchPlaylists({required String token}) async {
    _logger.i("Attempting to fetch playlists.");
    try {
      final response = await _api.get('playlists', token: token);
      final List<dynamic> data = response['data'];
      final playlists = data.map((json) => Playlist.fromJson(json)).toList();
      _logger.i("Successfully fetched ${playlists.length} playlists.");
      return playlists;
    } catch (e, s) {
      _logger.e("Error fetching playlists", e, s);
      rethrow;
    }
  }

  /// Fetches the full details of a single playlist, including all its items.
  Future<Playlist> fetchPlaylistDetails(
      {required int playlistId, required String token}) async {
    _logger.i("Fetching details for playlist ID: $playlistId.");
    try {
      final response = await _api.get('playlists/$playlistId', token: token);
      final playlist = Playlist.fromJson(response['data']);
      _logger.i(
          "Successfully fetched details for playlist '${playlist.name}'. Found ${playlist.items?.length ?? 0} items.");
      return playlist;
    } catch (e, s) {
      _logger.e("Error fetching playlist details for ID: $playlistId", e, s);
      rethrow;
    }
  }

  /// Creates a new, empty playlist.
  Future<Playlist> createPlaylist(
      {required String name, required String token}) async {
    _logger.i("Attempting to create new playlist '$name'.");
    final body = {'name': name.trim()};
    try {
      final response = await _api.post('playlists', body, token: token);
      final newPlaylist = Playlist.fromJson(response['data']);
      _logger.i("Successfully created playlist '${newPlaylist.name}'.");
      return newPlaylist;
    } catch (e, s) {
      _logger.e("Failed to create playlist '$name'", e, s);
      rethrow;
    }
  }

  /// Deletes an entire playlist.
  Future<void> deletePlaylist(
      {required int playlistId, required String token}) async {
    _logger.i("Attempting to delete playlist ID: $playlistId.");
    try {
      await _api.delete('playlists/$playlistId', token: token);
      _logger.i("Successfully deleted playlist ID: $playlistId.");
    } catch (e, s) {
      _logger.e("Failed to delete playlist ID: $playlistId", e, s);
      rethrow;
    }
  }

  /// Adds an episode to a playlist.
  /// Returns the updated playlist.
  Future<Playlist> addEpisodeToPlaylist({
    required int playlistId,
    required int episodeId,
    required ContentType type,
    required String token,
  }) async {
    _logger.i(
        "Adding episode ID: $episodeId (type: ${type.apiName}) to playlist ID: $playlistId");
    final body = {'episode_id': episodeId, 'type': type.apiName};
    try {
      final response =
          await _api.post('playlists/$playlistId/items', body, token: token);
      final updatedPlaylist = Playlist.fromJson(response['data']);
      _logger.i(
          "Successfully added episode. Playlist now has ${updatedPlaylist.items?.length ?? 0} items.");
      return updatedPlaylist;
    } catch (e, s) {
      _logger.e("Failed to add episode to playlist ID: $playlistId", e, s);
      rethrow;
    }
  }

  /// Removes a specific item from a playlist using its unique `playlistItemId`.
  Future<void> removeEpisodeFromPlaylist({
    required int playlistId,
    required int playlistItemId,
    required String token,
  }) async {
    _logger
        .i("Removing item ID: $playlistItemId from playlist ID: $playlistId");
    try {
      await _api.delete('playlists/$playlistId/items/$playlistItemId',
          token: token);
      _logger.i("Successfully removed item ID: $playlistItemId.");
    } catch (e, s) {
      _logger.e("Failed to remove item ID: $playlistItemId", e, s);
      rethrow;
    }
  }

  /// A helper method that handles creating a playlist and adding an episode in one go.
  Future<Playlist> createNewPlaylistAndAddEpisode({
    required String newPlaylistName,
    required int episodeId,
    required ContentType type,
    required String token,
  }) async {
    _logger.i(
        "Starting two-step process: Create playlist '$newPlaylistName' and add episode.");
    try {
      // 1. Create the new playlist
      final newPlaylist =
          await createPlaylist(name: newPlaylistName, token: token);

      // 2. Add the episode to the newly created playlist
      final updatedPlaylist = await addEpisodeToPlaylist(
        playlistId: newPlaylist.id,
        episodeId: episodeId,
        type: type,
        token: token,
      );
      _logger.i("Successfully created playlist and added episode.");
      return updatedPlaylist;
    } catch (e, s) {
      _logger.e("Error during createNewPlaylistAndAddEpisode", e, s);
      rethrow;
    }
  }
}
