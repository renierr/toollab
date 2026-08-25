import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';
import 'package:tool_lab/tools/file_manager/file_manager_installed_apps.dart';

class FileManagerSystemLoader {
  FileManagerSystemLoader._();

  static List<String> systemRoots() {
    if (Platform.isAndroid) {
      return const ['/system', '/vendor', '/etc', '/data', '/cache'];
    }
    if (Platform.isWindows) {
      final windowsDir = Platform.environment['SystemRoot'] ?? r'C:\Windows';
      return [
        windowsDir,
        r'C:\Program Files',
        r'C:\Program Files (x86)',
        r'C:\ProgramData',
      ];
    }
    return const [];
  }

  static Future<List<FileManagerEntry>> loadSystemEntries() async {
    final entries = <FileManagerEntry>[];
    for (final root in systemRoots()) {
      final stat = await FileSystemEntity.type(root);
      if (stat == FileSystemEntityType.notFound) continue;
      entries.add(
        FileManagerEntry(
          name: p.basename(root) == '' ? root : p.basename(root),
          path: root,
          isDirectory: true,
        ),
      );
    }
    return entries;
  }

  static Future<
    ({List<FileManagerAppInfo> apps, FileManagerStorageInfo? storage})
  >
  loadInstalledApps() async {
    final apps = await FileManagerInstalledApps.list();
    final storage = await FileManagerInstalledApps.storageInfo();
    return (apps: apps, storage: storage);
  }
}
