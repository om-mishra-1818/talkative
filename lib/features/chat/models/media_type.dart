enum MediaType { text, audio, video }

extension MediaTypeExt on MediaType {
  String get name {
    switch (this) {
      case MediaType.text:
        return 'text';
      case MediaType.audio:
        return 'audio';
      case MediaType.video:
        return 'video';
    }
  }

  static MediaType fromString(String val) {
    switch (val) {
      case 'audio':
        return MediaType.audio;
      case 'video':
        return MediaType.video;
      default:
        return MediaType.text;
    }
  }
}
