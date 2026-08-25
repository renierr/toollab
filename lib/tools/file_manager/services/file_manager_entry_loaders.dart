import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';

/// Lazily backs explorer rows with local stats and child counts, at most two
/// lookups in flight per pool so a deep tree never stalls the listing.
class FileManagerEntryLoaders {
  final Map<String, ValueNotifier<FileStat?>> _metadata = {};
  final ValueNotifier<FileStat?> _emptyMetadata = ValueNotifier<FileStat?>(
    null,
  );
  final List<FileManagerEntry> _metadataQueue = [];
  final Set<String> _queuedMetadataPaths = {};
  int _activeMetadataLoads = 0;

  final Map<String, ValueNotifier<int?>> _childCounts = {};
  final ValueNotifier<int?> _emptyChildCount = ValueNotifier<int?>(null);
  final List<String> _childCountQueue = [];
  final Set<String> _queuedChildCountPaths = {};
  int _activeChildCountLoads = 0;

  /// [request] false for entries that can't have local metadata (already
  /// stamped, archive entries, remote locations) — they share one empty
  /// notifier instead of pooling their own.
  ValueListenable<FileStat?> metadataFor(
    FileManagerEntry entry, {
    required bool request,
  }) {
    if (!request) return _emptyMetadata;
    final notifier = _metadata.putIfAbsent(
      entry.path,
      () => ValueNotifier<FileStat?>(null),
    );
    if (!_queuedMetadataPaths.contains(entry.path) && notifier.value == null) {
      _queuedMetadataPaths.add(entry.path);
      _metadataQueue.add(entry);
      _startMetadataLoads();
    }
    return notifier;
  }

  void _startMetadataLoads() {
    while (_activeMetadataLoads < 2 && _metadataQueue.isNotEmpty) {
      final entry = _metadataQueue.removeAt(0);
      _activeMetadataLoads++;
      FileStat.stat(entry.path)
          .then((stat) => _metadata[entry.path]?.value = stat)
          .catchError((_) => null)
          .whenComplete(() {
            _activeMetadataLoads--;
            _startMetadataLoads();
          });
    }
  }

  /// Same contract as [metadataFor] for folder child counts; [request] false
  /// for non-directories, broken links, archive entries and remote locations.
  ValueListenable<int?> childCountFor(
    FileManagerEntry entry, {
    required bool request,
  }) {
    if (!request) return _emptyChildCount;
    final notifier = _childCounts.putIfAbsent(
      entry.path,
      () => ValueNotifier<int?>(null),
    );
    if (!_queuedChildCountPaths.contains(entry.path) &&
        notifier.value == null) {
      _queuedChildCountPaths.add(entry.path);
      _childCountQueue.add(entry.path);
      _startChildCountLoads();
    }
    return notifier;
  }

  void _startChildCountLoads() {
    while (_activeChildCountLoads < 2 && _childCountQueue.isNotEmpty) {
      final path = _childCountQueue.removeAt(0);
      _activeChildCountLoads++;
      _countChildren(path)
          .then((count) => _childCounts[path]?.value = count)
          .catchError((_) => null)
          .whenComplete(() {
            _activeChildCountLoads--;
            _startChildCountLoads();
          });
    }
  }

  Future<int?> _countChildren(String path) async {
    try {
      var count = 0;
      await for (final _ in Directory(path).list(followLinks: false)) {
        count++;
      }
      return count;
    } catch (_) {
      return null;
    }
  }

  void reset() {
    for (final notifier in _metadata.values) {
      notifier.dispose();
    }
    for (final notifier in _childCounts.values) {
      notifier.dispose();
    }
    _childCounts.clear();
    _childCountQueue.clear();
    _queuedChildCountPaths.clear();
    _activeChildCountLoads = 0;
    _metadata.clear();
    _metadataQueue.clear();
    _queuedMetadataPaths.clear();
    _activeMetadataLoads = 0;
  }

  void dispose() {
    reset();
    _emptyMetadata.dispose();
    _emptyChildCount.dispose();
  }
}
