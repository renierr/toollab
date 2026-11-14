enum DeepSeekUploadStatus { uploading, ready, failed }

/// A file picked for the next DeepSeek message, uploaded as soon as it is
/// picked, like the web app does.
class DeepSeekAttachment {
  final String path;
  final String name;
  final DeepSeekUploadStatus status;

  /// The id the message references once DeepSeek has parsed the file.
  final String? fileId;

  const DeepSeekAttachment({
    required this.path,
    required this.name,
    this.status = DeepSeekUploadStatus.uploading,
    this.fileId,
  });

  bool get isImage => isImageName(name);

  DeepSeekAttachment ready(String id) => DeepSeekAttachment(
    path: path,
    name: name,
    status: DeepSeekUploadStatus.ready,
    fileId: id,
  );

  DeepSeekAttachment failed() => DeepSeekAttachment(
    path: path,
    name: name,
    status: DeepSeekUploadStatus.failed,
  );

  static const Set<String> imageExtensions = {
    'png',
    'jpg',
    'jpeg',
    'webp',
    'gif',
    'bmp',
    'heic',
  };

  static bool isImageName(String name) =>
      imageExtensions.contains(name.split('.').last.toLowerCase());
}
