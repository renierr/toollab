import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tool_lab/helpers/debug_log.dart';

/// Resolves Windows user shell folders (Pictures, Downloads, ...) from the
/// registry instead of guessing `%USERPROFILE%\<name>`.
///
/// Guessing breaks whenever a folder is redirected (OneDrive Known Folder Move,
/// roaming profiles) or localized — "Bilder" instead of "Pictures". The
/// `User Shell Folders` key is the same data Explorer reads.
class WindowsKnownFolders {
  WindowsKnownFolders._();

  static const _keyPath =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders';

  /// Registry value names. GUIDs are used for folders that have no legacy name.
  static const pictures = 'My Pictures';
  static const downloads = '{374DE290-123F-4565-9164-39C4925E467B}';
  static const cameraRoll = '{AB5FB87B-7CE2-4F83-915D-550846C9537B}';
  static const music = 'My Music';
  static const videos = 'My Video';
  static const documents = 'Personal';
  static const desktop = 'Desktop';

  static Map<String, String>? _cache;

  /// Cached, since the registry read spawns a process and the values only
  /// change when the user moves a library folder.
  static Future<Map<String, String>> all() async {
    if (!Platform.isWindows) return const {};
    final cached = _cache;
    if (cached != null) return cached;
    final folders = <String, String>{};
    try {
      final result = await Process.run('reg', ['query', _keyPath]);
      if (result.exitCode == 0) {
        final pattern = RegExp(r'^\s+(.+?)\s{2,}REG_[A-Z_]+\s{2,}(.+)$');
        for (final line in (result.stdout as String).split('\n')) {
          final match = pattern.firstMatch(line.trimRight());
          if (match == null) continue;
          folders[match.group(1)!] = _expand(match.group(2)!);
        }
      } else {
        errorLog('WindowsKnownFolders: reg query failed: ${result.stderr}');
      }
    } catch (e) {
      errorLog('WindowsKnownFolders: reg query error: $e');
    }
    _cache = folders;
    return folders;
  }

  /// Returns the folder path, or the `%USERPROFILE%\<fallbackName>` guess when
  /// the registry has no usable value.
  static Future<String?> path(String value, {String? fallbackName}) async {
    final resolved = (await all())[value];
    if (resolved != null && resolved.isNotEmpty) return resolved;
    final home = Platform.environment['USERPROFILE'];
    if (home == null || fallbackName == null) return null;
    return p.join(home, fallbackName);
  }

  /// Existing paths for the given value names, deduplicated. A redirected
  /// folder and a leftover local one can both hold files, so both are kept.
  static Future<List<String>> existingPaths(
    Iterable<String> values, {
    Iterable<String> extraGuesses = const [],
  }) async {
    final folders = await all();
    final home = Platform.environment['USERPROFILE'];
    final candidates = <String>{
      for (final value in values)
        if (folders[value] case final path? when path.isNotEmpty) path,
      if (home != null)
        for (final guess in extraGuesses) p.join(home, guess),
    };
    final existing = <String>[];
    for (final candidate in candidates) {
      try {
        if (await Directory(candidate).exists()) existing.add(candidate);
      } catch (_) {
        continue;
      }
    }
    return existing;
  }

  static String _expand(String raw) => raw.replaceAllMapped(
    RegExp(r'%([^%]+)%'),
    (match) => Platform.environment[match.group(1)!] ?? match.group(0)!,
  );
}
