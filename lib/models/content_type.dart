enum ContentType {
  commentary,
  course,
  deeperLook,
  story,
  surah;

  /// Returns the string value used in API request bodies (e.g., 'deeper_look').
  String get apiName {
    switch (this) {
      case ContentType.deeperLook:
        return 'deeper_look';
      default:
        return name;
    }
  }

  /// Returns the plural form for API URI endpoints (e.g., 'deeper-looks').
  String get apiEndpoint {
    switch (this) {
      case ContentType.commentary:
        return 'commentaries';
      case ContentType.deeperLook:
        return 'deeper-looks';
      case ContentType.story:
        return 'stories';
      default:
        return '${name}s';
    }
  }

  /// Returns the key for the main title/name of the content object.
  String get titleKey {
    switch (this) {
      case ContentType.commentary:
        return 'title';
      default:
        return 'name';
    }
  }

  /// Returns the key for the main image of the content object.
  String get imageKey {
    switch (this) {
      case ContentType.course:
        return 'image_path';
      default:
        return 'image';
    }
  }

  /// Returns the key for an episode's title/name.
  String get episodeTitleKey {
    switch (this) {
      case ContentType.commentary:
        return 'title';
      default:
        return 'name';
    }
  }
}
