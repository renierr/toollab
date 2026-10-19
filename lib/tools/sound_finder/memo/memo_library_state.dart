import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'memo_clip.dart';
import 'memo_player.dart';
import 'memo_store.dart';

/// Backs the memo list: the stored clips and the edits run on them. Edits
/// stop playback of the clip first so SoLoud never streams a file mid-rewrite.
class MemoLibraryState extends ChangeNotifier {
  MemoLibraryState(this.player) {
    MemoStore.revision.addListener(_onStoreChanged);
    unawaited(load());
  }

  static const _logPrefix = '[MemoLibrary]';

  final MemoPlayer player;
  List<MemoClip> _clips = const [];
  bool _loading = true;
  final Set<String> _busy = {};
  bool _disposed = false;

  List<MemoClip> get clips => _clips;
  bool get loading => _loading;
  int get totalBytes => _clips.fold(0, (sum, c) => sum + c.sizeBytes);
  bool isBusy(String path) => _busy.contains(path);

  void _onStoreChanged() => unawaited(load());

  Future<void> load() async {
    try {
      final clips = await MemoStore.list();
      if (_disposed) return;
      _clips = clips;
    } catch (e) {
      errorLog('$_logPrefix load failed: $e');
    }
    _loading = false;
    _notify();
  }

  Future<bool> rename(MemoClip clip, String name) => _edit(clip, () async {
    return await MemoStore.rename(clip, name) != null;
  });

  Future<bool> delete(MemoClip clip) => _edit(clip, () async {
    await MemoStore.delete(clip);
    return true;
  });

  Future<bool> trim(
    MemoClip clip,
    Duration start,
    Duration end, {
    required bool asCopy,
  }) => _edit(clip, () async {
    return await MemoStore.trim(clip, start, end, asCopy: asCopy) != null;
  }, stopPlayback: !asCopy);

  Future<bool> normalize(MemoClip clip) =>
      _edit(clip, () => MemoStore.normalize(clip));

  Future<bool> _edit(
    MemoClip clip,
    Future<bool> Function() action, {
    bool stopPlayback = true,
  }) async {
    if (_busy.contains(clip.path)) return false;
    if (stopPlayback && player.isCurrent(clip.path)) await player.stop();
    _busy.add(clip.path);
    _notify();
    try {
      return await action();
    } catch (e) {
      errorLog('$_logPrefix edit of ${clip.fileName} failed: $e');
      return false;
    } finally {
      _busy.remove(clip.path);
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    MemoStore.revision.removeListener(_onStoreChanged);
    super.dispose();
  }
}
