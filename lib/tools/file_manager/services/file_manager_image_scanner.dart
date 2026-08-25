import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tool_lab/helpers/windows_known_folders.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';
import 'package:tool_lab/tools/file_manager/file_manager_storage_access.dart';

class FileManagerImageScanner {
  FileManagerImageScanner._();

  static const _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
  };

  static bool _isImagePath(String path) => _imageExtensions.contains(
    p.extension(path).replaceFirst('.', '').toLowerCase(),
  );

  static int _compareModifiedDesc(FileManagerEntry a, FileManagerEntry b) =>
      (b.modified?.millisecondsSinceEpoch ?? 0).compareTo(
        a.modified?.millisecondsSinceEpoch ?? 0,
      );

  static Future<List<String>> roots({
    required bool usesSharedStorage,
    required String sharedStoragePath,
  }) async {
    if (FileManagerStorageAccess.isAndroid && usesSharedStorage) {
      return [
        'DCIM',
        'Pictures',
        'Download',
      ].map((dir) => p.join(sharedStoragePath, dir)).toList();
    }
    if (Platform.isWindows) {
      return WindowsKnownFolders.existingPaths(
        const [
          WindowsKnownFolders.pictures,
          WindowsKnownFolders.cameraRoll,
          WindowsKnownFolders.downloads,
        ],
        // A OneDrive-redirected library can leave files behind in the local
        // folder, so scan the plain guesses too when they still exist.
        extraGuesses: const ['Pictures', 'Downloads'],
      );
    }
    if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) return [p.join(home, 'Pictures')];
    }
    return const [];
  }

  /// Depth-first walk over [roots]; reports a newest-first snapshot through
  /// [onUpdate] at most every 250 ms while [isCancelled] stays false, then
  /// returns the final sorted listing.
  static Future<List<FileManagerEntry>> scan({
    required List<String> roots,
    required void Function(List<FileManagerEntry> entries) onUpdate,
    required bool Function() isCancelled,
  }) async {
    final images = <FileManagerEntry>[];
    final pending = [for (final root in roots) Directory(root)];
    var lastNotify = DateTime.now();
    var dirty = false;
    while (pending.isNotEmpty) {
      final directory = pending.removeLast();
      List<FileSystemEntity> children;
      try {
        children = await directory.list(followLinks: false).toList();
      } catch (_) {
        continue;
      }
      for (final entity in children) {
        if (entity is Directory) {
          if (p.basename(entity.path).startsWith('.')) continue;
          try {
            if (await File(p.join(entity.path, '.nomedia')).exists()) continue;
          } catch (_) {
            continue;
          }
          pending.add(entity);
        } else if (entity is File && _isImagePath(entity.path)) {
          try {
            final stat = await entity.stat();
            images.add(
              FileManagerEntry(
                name: p.basename(entity.path),
                path: entity.path,
                isDirectory: false,
                size: stat.size,
                modified: stat.modified,
              ),
            );
            dirty = true;
          } catch (_) {
            continue;
          }
        }
      }
      // Sorting the whole list per directory would be O(dirs * n log n);
      // only sort when a throttled UI update actually reads it.
      final now = DateTime.now();
      if (!isCancelled() && now.difference(lastNotify).inMilliseconds >= 250) {
        if (dirty) {
          images.sort(_compareModifiedDesc);
          dirty = false;
        }
        onUpdate(List.of(images));
        lastNotify = now;
      }
    }
    if (dirty) {
      images.sort(_compareModifiedDesc);
    }
    return images;
  }
}
