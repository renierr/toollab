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
  bool _loaded = false;

  VideoPlayerState({VideoHistoryDbHelper? db})
    : _db = db ?? VideoHistoryDbHelper.instance;

  List<VideoHistoryEntry> get entries => _entries;

  Future<void> load() async {
    try {
      _entries = await _db.recent();
      _loaded = true;
      notifyListeners();
    } catch (e) {
      errorLog('[VideoPlayerState] Loading history failed: $e');
    }
  }

  /// Frees the list after the tool closes; the database keeps it.
  void release() {
    _entries = const [];
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
    final entry = VideoHistoryEntry(
      source: source.toString(),
      title: title,
      positionMs: position.inMilliseconds,
      durationMs: duration.inMilliseconds,
      playedAt: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      if (await _db.save(entry)) {
        for (final source in await _db.prune(maxEntries)) {
          await VideoSystemChannel.release(Uri.parse(source));
        }
      }
      if (!_loaded) return;
      _entries = [
        entry,
        ..._entries.where((e) => e.source != entry.source),
      ].take(maxEntries).toList();
      notifyListeners();
    } catch (e) {
      errorLog('[VideoPlayerState] Saving position failed: $e');
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
