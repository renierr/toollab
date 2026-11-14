import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';

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

  /// Deletes the copies Android's pickers leave in the app cache once a file
  /// is no longer needed; anywhere else the path is the user's own file.
  static Future<void> discardPickerCopies(
    Iterable<DeepSeekAttachment> files,
  ) async {
    if (!Platform.isAndroid || files.isEmpty) return;
    final cache = (await getTemporaryDirectory()).path;
    for (final file in files) {
      if (!p.isWithin(cache, file.path)) continue;
      try {
        await File(file.path).delete();
      } on FileSystemException catch (e) {
        debugLog('[DeepSeekAttachment] Could not delete ${file.path}: $e');
      }
    }
  }

  static bool isImageName(String name) =>
      imageExtensions.contains(name.split('.').last.toLowerCase());
}
