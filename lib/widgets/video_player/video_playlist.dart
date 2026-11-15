import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tool_lab/helpers/debug_log.dart';

const List<String> videoFileExtensions = [
  'mp4',
  'm4v',
  'mkv',
  'webm',
  'mov',
  'avi',
  '3gp',
  'ts',
  'mts',
  'm2ts',
  'mpg',
  'mpeg',
  'ogv',
  'wmv',
  'flv',
];

class VideoPlaylistItem {
  final Uri source;
  final String title;

  const VideoPlaylistItem({required this.source, required this.title});
}

/// The videos in the folder of a local file, sorted by name; empty otherwise.
Future<List<VideoPlaylistItem>> videoFolderPlaylist(Uri source) async {
  if (!source.isScheme('file')) return const [];
  try {
    final items = <VideoPlaylistItem>[];
    final folder = File.fromUri(source).parent;
    await for (final entity in folder.list(followLinks: false)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (ext.isEmpty || !videoFileExtensions.contains(ext.substring(1))) {
        continue;
      }
      items.add(
        VideoPlaylistItem(
          source: Uri.file(entity.path),
          title: p.basename(entity.path),
        ),
      );
    }
    items.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return items;
  } catch (e) {
    debugLog('[VideoPlaylist] Folder scan failed: $e');
    return const [];
  }
}
