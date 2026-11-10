enum XMediaType { photo, video, gif }

class XMedia {
  final XMediaType type;

  /// The still image: the photo itself, or a video's preview frame.
  final String imageUrl;
  final int width;
  final int height;
  final String? videoUrl;
  final int? durationMs;
  final String? altText;

  const XMedia({
    required this.type,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.videoUrl,
    this.durationMs,
    this.altText,
  });

  bool get isPlayable => videoUrl != null;

  double get aspectRatio => width > 0 && height > 0 ? width / height : 16 / 9;

  /// pbs.twimg.com picks the rendition from `name`; `orig` is the upload.
  String imageVariant(String name) {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null) return imageUrl;
    final dot = uri.path.lastIndexOf('.');
    if (dot < 0) return imageUrl;
    final format = uri.path.substring(dot + 1);
    return uri
        .replace(
          path: uri.path.substring(0, dot),
          queryParameters: {'format': format, 'name': name},
        )
        .toString();
  }

  String get previewUrl => imageVariant('small');
  String get fullUrl => imageVariant('large');
  String get originalUrl => imageVariant('orig');

  String get fileExtension {
    if (isPlayable) return 'mp4';
    final path = Uri.tryParse(imageUrl)?.path ?? '';
    final dot = path.lastIndexOf('.');
    return dot < 0 ? 'jpg' : path.substring(dot + 1);
  }

  String get mimeType => isPlayable
      ? 'video/mp4'
      : fileExtension == 'png'
      ? 'image/png'
      : 'image/jpeg';
}
