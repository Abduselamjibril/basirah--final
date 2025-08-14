class GenericEpisode {
  final int id;
  final String title;
  final String? videoUrl;
  final String? audioUrl;
  final String? youtubeLink;
  final bool isLocked;
  final String type;
  final int parentId;
  final String? imageUrl;
  final bool isDeleted;

  GenericEpisode({
    required this.id,
    required this.title,
    this.videoUrl,
    this.audioUrl,
    this.youtubeLink,
    required this.isLocked,
    required this.type,
    required this.parentId,
    this.imageUrl,
    this.isDeleted = false,
  });

  GenericEpisode.deleted({required String title})
      : id = 0,
        this.title = title,
        videoUrl = null,
        audioUrl = null,
        youtubeLink = null,
        isLocked = false,
        type = 'deleted',
        parentId = 0,
        imageUrl = null,
        isDeleted = true;

  factory GenericEpisode.fromJson(Map<String, dynamic> json) {
    // --- FIX APPLIED HERE ---

    // 1. A robust helper function to safely parse a value into an integer.
    // It can handle nulls, integers, and strings without crashing.
    int _parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0; // Fallback for other unexpected types
    }

    // 2. The _findParentId function now uses the safe parser.
    int _findParentId(String type, Map<String, dynamic> data) {
      if (type == 'unknown') return 0;
      final key = '${type}_id';
      return _parseInt(data[key]);
    }

    // --- END FIX ---

    final type = json['type'] as String? ?? 'unknown';

    return GenericEpisode(
      // 3. The safe parser is also used for the main episode ID.
      id: _parseInt(json['id']),
      title: json['title'] as String? ?? json['name'] as String? ?? 'Untitled',
      videoUrl: json['video_url'] as String? ??
          json['video_path'] as String? ??
          json['video'] as String?,
      audioUrl: json['audio_url'] as String? ??
          json['audio_path'] as String? ??
          json['audio'] as String?,
      youtubeLink: json['youtube_link'] as String?,
      isLocked: (json['is_locked'] == 1 || json['is_locked'] == true),
      type: type,
      parentId: _findParentId(type, json),
      imageUrl: json['image_path'] as String? ?? json['image'] as String?,
    );
  }
}
