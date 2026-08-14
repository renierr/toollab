import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, kProfileMode;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/services/database_service.dart';

import 'sqlite_models.dart';

/// Copies a database plus its `-wal` / `-shm` sidecars into [scope] and returns
/// the copy's path. Without the sidecars a WAL database would be missing its
/// most recent commits, and opening the live app database in place would fight
/// the connection ToolLab already holds.
Future<String> copyDatabaseSnapshot(
  TempFileScope scope,
  String sourcePath,
) async {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final baseName = 'sqlite_view_${stamp}_${p.basename(sourcePath)}';
  final destPath = await scope.createFile(baseName);
  await File(sourcePath).copy(destPath);

  for (final suffix in const ['-wal', '-shm']) {
    final sidecar = File('$sourcePath$suffix');
    if (!await sidecar.exists()) continue;
    final sidecarDest = await scope.createFile('$baseName$suffix');
    await sidecar.copy(sidecarDest);
  }
  return destPath;
}

/// Lists ToolLab's own database files in the app support directory, newest
/// first, with the live connection's file flagged.
Future<List<InternalDbEntry>> listInternalDatabases() async {
  final entries = <InternalDbEntry>[];
  try {
    final livePath = (await DatabaseService.instance.database).path;
    final support = await getApplicationSupportDirectory();
    final modeSubdir = kReleaseMode ? '' : (kProfileMode ? 'profile' : 'debug');
    final dirs = <Directory>{
      support,
      Directory(p.join(support.path, modeSubdir)),
      Directory(p.dirname(livePath)),
    };

    final seen = <String>{};
    for (final dir in dirs) {
      if (!await dir.exists()) continue;
      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final ext = p.extension(entity.path).toLowerCase();
        if (ext != '.db' && ext != '.sqlite' && ext != '.sqlite3') continue;
        if (!seen.add(p.normalize(entity.path))) continue;
        entries.add(
          InternalDbEntry(
            name: p.basename(entity.path),
            path: entity.path,
            sizeBytes: await entity.length(),
            isLiveAppDatabase: p.equals(entity.path, livePath),
          ),
        );
      }
    }
  } catch (e) {
    errorLog('SqliteViewer: internal database scan failed: $e');
  }
  entries.sort((a, b) => a.name.compareTo(b.name));
  return entries;
}
