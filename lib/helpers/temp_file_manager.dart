import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class TempFileManager {
  TempFileManager._();

  static Directory? _baseDir;
  static Directory? _sessionDir;
  static final List<String> _tracked = [];

  static String get _namespace => 'tool_lab';

  static Future<Directory> get _base async {
    if (_baseDir != null) return _baseDir!;
    final root = await getTemporaryDirectory();
    _baseDir = Directory('${root.path}/$_namespace');
    await _baseDir!.create(recursive: true);
    return _baseDir!;
  }

  /// Creates a new session dir. Orphan cleanup runs in background.
  static Future<void> init() async {
    final base = await _base;
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _sessionDir = Directory('${base.path}/$sessionId');
    await _sessionDir!.create(recursive: true);
    // fire-and-forget orphan cleanup
    _cleanupOrphans(base);
  }

  static Future<void> _cleanupOrphans(Directory base) async {
    try {
      final entries = base.listSync();
      for (final entry in entries) {
        if (entry is Directory && entry.path != _sessionDir?.path) {
          await entry.delete(recursive: true);
        }
      }
    } catch (e) {
      debugPrint('TempFileManager: orphan cleanup error: $e');
    }
  }

  static Future<Directory> get sessionDir async {
    _sessionDir ??= await _createSession();
    return _sessionDir!;
  }

  static Future<Directory> _createSession() async {
    final base = await _base;
    final dir = Directory(
      '${base.path}/${DateTime.now().millisecondsSinceEpoch.toString()}',
    );
    await dir.create(recursive: true);
    return dir;
  }

  /// Create a tracked temp file. Returns the absolute path.
  static Future<String> createFile(String name, {Uint8List? bytes}) async {
    final dir = await sessionDir;
    final file = File('${dir.path}/$name');
    await file.create(recursive: true);
    if (bytes != null) await file.writeAsBytes(bytes);
    if (!_tracked.contains(name)) _tracked.add(name);
    return file.path;
  }

  /// Read bytes from a tracked temp file.
  static Future<Uint8List> readFile(String name) async {
    final file = await resolveFile(name);
    return await file.readAsBytes();
  }

  /// Resolve a [File] reference within the session dir.
  static Future<File> resolveFile(String name) async {
    final dir = await sessionDir;
    return File('${dir.path}/$name');
  }

  /// Delete a single tracked file.
  static Future<void> deleteFile(String name) async {
    final file = await resolveFile(name);
    if (await file.exists()) await file.delete();
    _tracked.remove(name);
  }

  /// Remove all tracked files for this session.
  static Future<void> cleanTracked() async {
    for (final name in _tracked.toList()) {
      await deleteFile(name);
    }
    _tracked.clear();
  }

  /// Delete the entire current session dir and all tracked files.
  static Future<void> cleanSession() async {
    if (_sessionDir != null && await _sessionDir!.exists()) {
      await _sessionDir!.delete(recursive: true);
    }
    _tracked.clear();
    _sessionDir = null;
    _baseDir = null;
  }

  /// Total bytes of tracked files.
  static Future<int> trackedBytes() async {
    int total = 0;
    for (final name in _tracked) {
      try {
        final file = await resolveFile(name);
        if (await file.exists()) total += await file.length();
      } catch (_) {}
    }
    return total;
  }

  /// Number of tracked files.
  static int get trackedCount => _tracked.length;
}
