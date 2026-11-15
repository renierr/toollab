import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/widgets/video_player/video_resume_store.dart';
import 'package:tool_lab/widgets/video_player/video_system_channel.dart';

import 'video_history_db_helper.dart';
import 'video_history_entry.dart';

/// Recently played videos and their resume positions.
class VideoPlayerState extends ChangeNotifier implements VideoResumeStore {
  static const int maxEntries = 50;

  final VideoHistoryDbHelper _db;
  List<VideoHistoryEntry> _entries = const [];
  Set<String> _missing = const {};
  bool _loaded = false;

  VideoPlayerState({VideoHistoryDbHelper? db})
    : _db = db ?? VideoHistoryDbHelper.instance;

  List<VideoHistoryEntry> get entries => _entries;

  /// A local file that is gone; content URIs are not checked.
  bool isMissing(VideoHistoryEntry entry) => _missing.contains(entry.source);

  Future<void> load() async {
    try {
      final entries = await _db.recent();
      final missing = <String>{};
      for (final entry in entries) {
        final uri = entry.uri;
        if (uri.isScheme('file') && !await File.fromUri(uri).exists()) {
          missing.add(entry.source);
        }
      }
      _entries = entries;
      _missing = missing;
      _loaded = true;
      notifyListeners();
    } catch (e) {
      errorLog('[VideoPlayerState] Loading history failed: $e');
    }
  }

  /// Frees the list after the tool closes; the database keeps it.
  void release() {
    _entries = const [];
    _missing = const {};
    _loaded = false;
  }

  @override
  Future<Duration?> resumePosition(Uri source) async {
    try {
      final entry = await _db.find(source.toString());
      return entry != null && entry.resumable ? entry.position : null;
    } catch (e) {
      errorLog('[VideoPlayerState] Reading position failed: $e');
      return null;
    }
  }

  @override
  Future<void> savePosition({
    required Uri source,
    required String title,
    required Duration position,
    required Duration duration,
  }) async {
    final key = source.toString();
    final entry = VideoHistoryEntry(
      source: key,
      title: title,
      positionMs: position.inMilliseconds,
      durationMs: duration.inMilliseconds,
      playedAt: DateTime.now().millisecondsSinceEpoch,
      thumbnail: _entries.where((e) => e.source == key).firstOrNull?.thumbnail,
    );
    try {
      if (await _db.save(entry)) {
        for (final source in await _db.prune(maxEntries)) {
          await VideoSystemChannel.release(Uri.parse(source));
        }
      }
      if (!_loaded) return;
      _missing = _missing.difference({key});
      _entries = [
        entry,
        ..._entries.where((e) => e.source != entry.source),
      ].take(maxEntries).toList();
      notifyListeners();
    } catch (e) {
      errorLog('[VideoPlayerState] Saving position failed: $e');
    }
  }

  @override
  Future<void> saveThumbnail(Uri source, Uint8List jpeg) async {
    final key = source.toString();
    try {
      await _db.saveThumbnail(key, jpeg);
      if (!_loaded) return;
      _entries = [
        for (final e in _entries)
          e.source == key
              ? VideoHistoryEntry(
                  source: e.source,
                  title: e.title,
                  positionMs: e.positionMs,
                  durationMs: e.durationMs,
                  playedAt: e.playedAt,
                  thumbnail: jpeg,
                )
              : e,
      ];
      notifyListeners();
    } catch (e) {
      errorLog('[VideoPlayerState] Saving thumbnail failed: $e');
    }
  }

  Future<void> remove(VideoHistoryEntry entry) async {
    try {
      await _db.delete(entry.source);
      await VideoSystemChannel.release(entry.uri);
      _entries = _entries.where((e) => e.source != entry.source).toList();
      notifyListeners();
    } catch (e) {
      errorLog('[VideoPlayerState] Removing entry failed: $e');
    }
  }

  Future<void> clear() async {
    try {
      for (final source in await _db.clear()) {
        await VideoSystemChannel.release(Uri.parse(source));
      }
      _entries = const [];
      notifyListeners();
    } catch (e) {
      errorLog('[VideoPlayerState] Clearing history failed: $e');
    }
  }
}
