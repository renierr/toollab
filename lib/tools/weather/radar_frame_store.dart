import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';

import 'weather_db_helper.dart';

/// Compressed radar images for the app session: an LRU in memory backed by
/// session temp files, so reopening the tool or panning back loads nothing.
class RadarFrameStore {
  RadarFrameStore({this._scope, this.memoryBudget = 24 * 1024 * 1024});

  final int memoryBudget;
  TempFileScope? _scope;
  final LinkedHashMap<String, Uint8List> _memory = LinkedHashMap();
  final Set<String> _onDisk = {};
  int _bytes = 0;

  TempFileScope get _files => _scope ??= TempFileManager.createScope();

  static String _fileName(String key) =>
      'weather_radar_${sha1.convert(utf8.encode(key))}.png';

  Future<Uint8List?> read(String key) async {
    final hit = _memory.remove(key);
    if (hit != null) {
      _memory[key] = hit;
      return hit;
    }
    if (!_onDisk.contains(key)) return null;
    try {
      final bytes = await _files.readFile(_fileName(key));
      _remember(key, bytes);
      return bytes;
    } on FileSystemException {
      _onDisk.remove(key);
      return null;
    }
  }

  Future<void> write(String key, Uint8List bytes) async {
    _remember(key, bytes);
    if (_onDisk.contains(key)) return;
    try {
      await _files.createFile(_fileName(key), bytes: bytes);
      _onDisk.add(key);
    } catch (e) {
      debugLog('[RadarFrameStore] write failed: $e');
    }
  }

  void _remember(String key, Uint8List bytes) {
    final old = _memory.remove(key);
    if (old != null) _bytes -= old.length;
    _memory[key] = bytes;
    _bytes += bytes.length;
    while (_bytes > memoryBudget && _memory.length > 1) {
      final first = _memory.keys.first;
      _bytes -= _memory.remove(first)!.length;
    }
  }

  /// Frees memory but keeps the session files.
  void dropMemory() {
    _memory.clear();
    _bytes = 0;
  }

  Future<void> clear() async {
    dropMemory();
    _onDisk.clear();
    await _scope?.cleanTracked();
  }
}

/// Radar images worth keeping across app starts: the static base map and the
/// last current frame, so the map shows instantly while fresh data loads.
class RadarLastingStore {
  RadarLastingStore();

  static const String _prefix = 'radar:';
  static const Duration _keep = Duration(days: 30);
  bool _pruned = false;

  Future<({Uint8List bytes, DateTime savedAt})?> read(String key) async {
    try {
      if (!_pruned) {
        _pruned = true;
        await WeatherDbHelper.instance.pruneCache(
          DateTime.now().subtract(_keep),
          prefix: _prefix,
        );
      }
      final entry = await WeatherDbHelper.instance.getCache('$_prefix$key');
      return entry == null
          ? null
          : (bytes: entry.body, savedAt: entry.fetchedAt);
    } catch (e) {
      debugLog('[RadarLastingStore] read failed: $e');
      return null;
    }
  }

  Future<void> write(String key, Uint8List bytes) async {
    try {
      await WeatherDbHelper.instance.putCache(
        '$_prefix$key',
        bytes,
        DateTime.now(),
      );
    } catch (e) {
      debugLog('[RadarLastingStore] write failed: $e');
    }
  }
}
