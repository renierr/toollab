import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';

enum StorageRootKind { appData, externalAppData, appSupport, cache, temp }

class StorageEntry {
  final String name;
  final String path;
  final int bytes;
  final int fileCount;
  final bool isDirectory;

  const StorageEntry({
    required this.name,
    required this.path,
    required this.bytes,
    required this.fileCount,
    required this.isDirectory,
  });
}

class StorageRoot {
  final StorageRootKind kind;
  final String path;

  /// Direct children, largest first.
  final List<StorageEntry> children;

  const StorageRoot({
    required this.kind,
    required this.path,
    required this.children,
  });

  int get bytes => children.fold(0, (sum, e) => sum + e.bytes);
}

class StorageUsageService {
  StorageUsageService._();

  /// Directories the app owns on this platform, measured recursively.
  static Future<List<StorageRoot>> roots() async {
    final dirs = <StorageRootKind, String>{};
    final support = await getApplicationSupportDirectory();
    if (Platform.isAndroid) {
      // files/ sits inside the app's data root next to app_flutter/, cache/,
      // databases/, shared_prefs/ and app_webview/.
      dirs[StorageRootKind.appData] = support.parent.path;
      try {
        final external = await getExternalStorageDirectory();
        if (external != null) {
          dirs[StorageRootKind.externalAppData] = external.parent.path;
        }
      } catch (e) {
        errorLog('StorageUsageService: external dir unavailable: $e');
      }
    } else {
      dirs[StorageRootKind.appSupport] = support.path;
      try {
        dirs[StorageRootKind.cache] =
            (await getApplicationCacheDirectory()).path;
      } catch (e) {
        errorLog('StorageUsageService: cache dir unavailable: $e');
      }
      // Only our namespace: the system temp dir is shared on desktop.
      dirs[StorageRootKind.temp] = p.join(
        (await getTemporaryDirectory()).path,
        'tool_lab',
      );
    }

    return Isolate.run(
      () => [
        for (final MapEntry(key: kind, value: path) in dirs.entries)
          if (Directory(path).existsSync())
            StorageRoot(kind: kind, path: path, children: _children(path)),
      ]..sort((a, b) => b.bytes.compareTo(a.bytes)),
    );
  }

  /// Direct children of [dirPath], largest first.
  static Future<List<StorageEntry>> children(String dirPath) =>
      Isolate.run(() => _children(dirPath));

  static List<StorageEntry> _children(String dirPath) {
    final List<FileSystemEntity> entities;
    try {
      entities = Directory(dirPath).listSync(followLinks: false);
    } catch (_) {
      return [];
    }
    return [
      for (final entity in entities)
        if (entity is! Link) ?_measure(entity.path),
    ]..sort((a, b) => b.bytes.compareTo(a.bytes));
  }

  static StorageEntry? _measure(String path) {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    final name = p.basename(path);
    if (type == FileSystemEntityType.file) {
      int size = 0;
      try {
        size = File(path).lengthSync();
      } catch (_) {}
      return StorageEntry(
        name: name,
        path: path,
        bytes: size,
        fileCount: 1,
        isDirectory: false,
      );
    }
    if (type != FileSystemEntityType.directory) return null;

    var bytes = 0;
    var files = 0;
    final pending = [Directory(path)];
    while (pending.isNotEmpty) {
      final dir = pending.removeLast();
      final List<FileSystemEntity> entities;
      try {
        entities = dir.listSync(followLinks: false);
      } catch (_) {
        continue;
      }
      for (final entity in entities) {
        if (entity is File) {
          try {
            bytes += entity.lengthSync();
            files++;
          } catch (_) {}
        } else if (entity is Directory) {
          pending.add(entity);
        }
      }
    }
    return StorageEntry(
      name: name,
      path: path,
      bytes: bytes,
      fileCount: files,
      isDirectory: true,
    );
  }
}
