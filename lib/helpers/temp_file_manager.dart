import 'dart:async';
import 'package:tool_lab/helpers/debug_log.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// ---------------------------------------------------------------------------
// Private raw I/O — no tracking, shared by both global and scope APIs
// ---------------------------------------------------------------------------

String _sessionPath(Directory dir, String name) => '${dir.path}/$name';

Future<String> _rawCreateFile(String name, {Uint8List? bytes}) async {
  final dir = await TempFileManager.sessionDir;
  final file = File(_sessionPath(dir, name));
  await file.create(recursive: true);
  if (bytes != null) await file.writeAsBytes(bytes);
  return file.path;
}

Future<File> _rawResolveFile(String name) async {
  final dir = await TempFileManager.sessionDir;
  return File(_sessionPath(dir, name));
}

Future<Uint8List> _rawReadFile(String name) async {
  return await (await _rawResolveFile(name)).readAsBytes();
}

Future<void> _rawDeleteFile(String name) async {
  final file = await _rawResolveFile(name);
  if (await file.exists()) await file.delete();
}

// ---------------------------------------------------------------------------
// Scope — per-widget/controller tracking
// ---------------------------------------------------------------------------

/// A scope that tracks temp files created within a widget/controller lifecycle.
/// Call [cleanTracked] on dispose to remove only this scope's files.
class TempFileScope {
  final List<String> _tracked = [];

  Future<String> createFile(String name, {Uint8List? bytes}) async {
    final path = await _rawCreateFile(name, bytes: bytes);
    if (!_tracked.contains(name)) _tracked.add(name);
    return path;
  }

  /// Registers a file already written into the session dir by native code
  /// (e.g. the Android streaming picker) so it shares this scope's lifecycle.
  void track(String name) {
    if (!_tracked.contains(name)) _tracked.add(name);
  }

  Future<Uint8List> readFile(String name) => _rawReadFile(name);

  Future<File> resolveFile(String name) => _rawResolveFile(name);

  Future<void> deleteFile(String name) async {
    await _rawDeleteFile(name);
    _tracked.remove(name);
  }

  Future<void> cleanTracked() async {
    for (final name in _tracked.toList()) {
      await _rawDeleteFile(name);
    }
    _tracked.clear();
  }

  int get trackedCount => _tracked.length;

  Future<int> trackedBytes() async {
    int total = 0;
    for (final name in _tracked) {
      try {
        final file = await _rawResolveFile(name);
        if (await file.exists()) total += await file.length();
      } catch (_) {}
    }
    return total;
  }
}

class TempFileManager {
  TempFileManager._();

  static Directory? _baseDir;
  static Directory? _sessionDir;
  static final List<String> _globalTracked = [];

  static String get _namespace => 'tool_lab';

  static Future<Directory> get _base async {
    if (_baseDir != null) return _baseDir!;
    final root = await getTemporaryDirectory();
    _baseDir = Directory('${root.path}/$_namespace');
    await _baseDir!.create(recursive: true);
    return _baseDir!;
  }

  static Future<Directory> get sessionDir async {
    _sessionDir ??= await _createSession();
    return _sessionDir!;
  }

  /// Creates a new session dir. Orphan cleanup runs in background.
  static Future<void> init() async {
    final base = await _base;
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _sessionDir = Directory('${base.path}/$sessionId');
    await _sessionDir!.create(recursive: true);
    _cleanupOrphans(base);
  }

  static void _cleanupOrphans(Directory base) {
    try {
      final entries = base.listSync();
      for (final entry in entries) {
        if (entry is Directory && entry.path != _sessionDir?.path) {
          unawaited(entry.delete(recursive: true));
        }
      }
    } catch (e) {
      errorLog('TempFileManager: orphan cleanup error: $e');
    }
  }

  static Future<Directory> _createSession() async {
    final base = await _base;
    final dir = Directory(
      '${base.path}/${DateTime.now().millisecondsSinceEpoch.toString()}',
    );
    await dir.create(recursive: true);
    return dir;
  }

  // ---------------------------------------------------------------------------
  // Global API – for StatelessWidgets / static helpers
  // ---------------------------------------------------------------------------

  static Future<String> createFile(String name, {Uint8List? bytes}) async {
    final path = await _rawCreateFile(name, bytes: bytes);
    if (!_globalTracked.contains(name)) _globalTracked.add(name);
    return path;
  }

  static Future<Uint8List> readFile(String name) => _rawReadFile(name);

  static Future<File> resolveFile(String name) => _rawResolveFile(name);

  static Future<void> deleteFile(String name) async {
    await _rawDeleteFile(name);
    _globalTracked.remove(name);
  }

  static Future<void> cleanTracked() async {
    for (final name in _globalTracked.toList()) {
      await _rawDeleteFile(name);
    }
    _globalTracked.clear();
  }

  static int get trackedCount => _globalTracked.length;

  static Future<int> trackedBytes() async {
    int total = 0;
    for (final name in _globalTracked) {
      try {
        final file = await _rawResolveFile(name);
        if (await file.exists()) total += await file.length();
      } catch (_) {}
    }
    return total;
  }

  // ---------------------------------------------------------------------------
  // Scope API
  // ---------------------------------------------------------------------------

  static TempFileScope createScope() => TempFileScope();

  // ---------------------------------------------------------------------------
  // Session-level cleanup
  // ---------------------------------------------------------------------------

  static Future<void> cleanSession() async {
    if (_sessionDir != null && await _sessionDir!.exists()) {
      await _sessionDir!.delete(recursive: true);
    }
    _globalTracked.clear();
    _sessionDir = null;
    _baseDir = null;
  }

  static Future<void> cleanAll() async {
    _globalTracked.clear();
    _sessionDir = null;
    if (_baseDir != null && await _baseDir!.exists()) {
      await _baseDir!.delete(recursive: true);
    }
    _baseDir = null;
    await init();
  }
}
