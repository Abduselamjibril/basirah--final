import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'playlist_detail_page.dart';
import '../../models/playlist/playlist.dart'; // Import the new model
import '../../providers/auth_provider.dart';
import '../../services/content_detail_services/api_service.dart';
import '../../services/content_detail_services/playlist_service.dart';
import '../../services/content_detail_services/ui_service.dart';
import '../../theme_provider.dart';

class PlaylistsTab extends StatefulWidget {
  @override
  _PlaylistsTabState createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends State<PlaylistsTab> {
  // Use the new strongly-typed model
  List<Playlist> _playlists = [];
  List<Playlist> _filteredPlaylists = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  late final PlaylistService _playlistService;
  late final UIService _uiService;

  @override
  void initState() {
    super.initState();
    // Using a singleton or dependency injection for services is recommended
    _playlistService = PlaylistService(ApiService());
    _uiService = UIService();
    _searchController.addListener(_filterPlaylists);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.addListener(_onAuthStateChanged);

    _initialize(authProvider);
  }

  void _onAuthStateChanged() {
    _initialize(Provider.of<AuthProvider>(context, listen: false));
  }

  @override
  void dispose() {
    Provider.of<AuthProvider>(context, listen: false)
        .removeListener(_onAuthStateChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initialize(AuthProvider authProvider) async {
    if (authProvider.token != null) {
      await _fetchPlaylists(authProvider.token!);
    } else if (mounted) {
      setState(() {
        _isLoading = false;
        _playlists = [];
        _filteredPlaylists = [];
      });
    }
  }

  Future<void> _fetchPlaylists(String token) async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final playlists = await _playlistService.fetchPlaylists(token: token);
      if (!mounted) return;
      setState(() {
        _playlists = playlists;
        _filterPlaylists();
      });
    } catch (e) {
      _uiService.showErrorSnackbar('Error loading playlists. Pull to refresh.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createPlaylist(String name) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;

    if (name.trim().isEmpty) {
      _uiService.showErrorSnackbar('Playlist name cannot be empty.');
      return;
    }

    // Optimistic UI update can be added here

    try {
      final newPlaylist =
          await _playlistService.createPlaylist(name: name, token: token);
      _uiService.showSuccessSnackbar('Playlist "${newPlaylist.name}" created.');

      // Add to list locally instead of a full refetch
      if (mounted) {
        setState(() {
          _playlists.insert(0, newPlaylist);
          _filterPlaylists();
        });
      }
    } catch (e) {
      _uiService.showErrorSnackbar('Failed to create playlist.');
    }
  }

  Future<void> _deletePlaylist(int playlistId) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;

    // Optimistic UI: remove immediately
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex == -1) return;
    final playlistToDelete = _playlists[playlistIndex];

    if (mounted) {
      setState(() {
        _playlists.removeAt(playlistIndex);
        _filterPlaylists();
      });
    }

    try {
      await _playlistService.deletePlaylist(
          playlistId: playlistId, token: token);
      _uiService.showSuccessSnackbar('Playlist deleted.');
    } catch (e) {
      // Revert if API call fails
      if (mounted) {
        setState(() {
          _playlists.insert(playlistIndex, playlistToDelete);
          _filterPlaylists();
        });
      }
      _uiService.showErrorSnackbar('Failed to delete playlist.');
    }
  }

  void _filterPlaylists() {
    if (!mounted) return;
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredPlaylists = query.isEmpty
          ? List<Playlist>.from(_playlists)
          : _playlists
              .where((p) => p.name.toLowerCase().contains(query))
              .toList();
    });
  }

  // --- UI DIALOGS (_showCreatePlaylistDialog, _showDeleteConfirmation) ---
  // No changes are needed in these dialog methods, they remain the same.
  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    final primaryColor = const Color(0xFF009B77);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Create New Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Playlist Name',
            labelStyle: TextStyle(color: primaryColor),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: primaryColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                final playlistName = controller.text;
                Navigator.pop(dialogContext);
                _createPlaylist(playlistName);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text('CREATE'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(int playlistId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Playlist'),
        content:
            Text('Are you sure you want to permanently delete this playlist?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('CANCEL')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePlaylist(playlistId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('DELETE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isNightMode = themeProvider.isDarkMode;
    final primaryColor = const Color(0xFF009B77);

    // Main scaffold structure remains the same
    return Scaffold(
      backgroundColor: isNightMode ? Color(0xFF002147) : Colors.grey[100],
      appBar: AppBar(
        title: Text('My Playlists',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: isNightMode ? const Color(0xFF002147) : primaryColor,
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search playlists...',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: isNightMode ? Color(0xFF1E1E1E) : Colors.white,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : !authProvider.isLoggedIn
                    ? _buildLoginPrompt()
                    : RefreshIndicator(
                        onRefresh: () => _fetchPlaylists(authProvider.token!),
                        child: _filteredPlaylists.isEmpty
                            ? _buildEmptyState()
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 80),
                                itemCount: _filteredPlaylists.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final playlist = _filteredPlaylists[index];
                                  return _buildPlaylistCard(playlist);
                                },
                              ),
                      ),
          ),
        ],
      ),
      floatingActionButton: authProvider.isLoggedIn
          ? FloatingActionButton(
              onPressed: _showCreatePlaylistDialog,
              child: Icon(Icons.add),
              backgroundColor: primaryColor,
            )
          : null,
    );
  }

  // Updated to use the Playlist model
  Widget _buildPlaylistCard(Playlist playlist) {
    final int totalEpisodes = playlist.itemsCount ?? 0;
    final String itemText = totalEpisodes == 1 ? "Item" : "Items";

    return Card(
      elevation: 1.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.queue_music_rounded,
            color: Theme.of(context).primaryColor),
        title:
            Text(playlist.name, style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$totalEpisodes $itemText'),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade300),
          onPressed: () => _showDeleteConfirmation(playlist.id),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlaylistDetailPage(
                  playlistId: playlist.id, playlistName: playlist.name),
            ),
          ).then((_) {
            // Re-fetch on return to update item counts if changed
            final authProvider =
                Provider.of<AuthProvider>(context, listen: false);
            if (authProvider.isLoggedIn) {
              _fetchPlaylists(authProvider.token!);
            }
          });
        },
      ),
    );
  }

  // --- EMPTY/LOGIN STATE WIDGETS (_buildEmptyState, _buildLoginPrompt) ---
  // No changes are needed in these widgets, they remain the same.
  Widget _buildEmptyState() {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Container(
          height: constraints.maxHeight,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                      _searchController.text.isEmpty
                          ? Icons.playlist_play_rounded
                          : Icons.search_off_rounded,
                      size: 70,
                      color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                      _searchController.text.isEmpty
                          ? 'No Playlists Yet'
                          : 'No Playlists Found',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Text(
                      _searchController.text.isEmpty
                          ? 'Tap the + button to create your first playlist.'
                          : 'Try a different search term.',
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.login_rounded, size: 70, color: Colors.grey),
          SizedBox(height: 20),
          Text('Please Log In',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text('Log in to create and view your personal playlists.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600])),
          ),
        ],
      ),
    );
  }
}
