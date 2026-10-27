import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'depot_logo_downloader.dart';
import 'depot_store.dart';
import 'models/depot_holding_logo.dart';

class DepotLogoState extends ChangeNotifier {
  DepotLogoState({this.downloader = const DepotLogoDownloader()}) {
    ensureLoaded();
  }

  final DepotLogoDownloader downloader;
  final _store = DepotStore.instance;
  final Map<String, DepotHoldingLogo> _logos = {};
  Future<void>? _loading;
  bool _isFetching = false;
  bool _disposed = false;
  bool _loadFailed = false;
  int _generation = 0;
  int _completed = 0;
  int _total = 0;
  int _failed = 0;

  bool get isFetching => _isFetching;
  bool get loadFailed => _loadFailed;
  int get cachedCount => _logos.length;
  int get completed => _completed;
  int get total => _total;
  int get failed => _failed;
  Uint8List? bytesFor(String key) => _logos[key]?.bytes;

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    final generation = _generation;
    try {
      final logos = await _store.holdingLogos();
      if (_disposed || generation != _generation) return;
      _logos.addEntries(logos.map((logo) => MapEntry(logo.key, logo)));
      _loadFailed = false;
    } catch (e) {
      _loadFailed = true;
      errorLog('[DepotLogoState] Loading logo cache failed: $e');
    }
    _notify();
  }

  // Called only by the explicit settings action, never by sync or avatars.
  Future<void> downloadMissing() async {
    if (_isFetching || _disposed) return;
    _isFetching = true;
    _failed = 0;
    _completed = 0;
    _total = 0;
    _notify();
    final generation = _generation;
    try {
      if (_loadFailed) _loading = null;
      await ensureLoaded();
      if (_loadFailed || _disposed || generation != _generation) return;
      final holdings = await _store.holdings();
      final urls = <String, String>{};
      for (final holding in holdings) {
        final key = holding.identifier ?? holding.id;
        final url = holding.logo?.trim();
        if (!_logos.containsKey(key) && url != null && url.isNotEmpty) {
          urls.putIfAbsent(key, () => url);
        }
      }
      final pending = urls.entries.toList();
      _total = pending.length;
      _notify();
      var next = 0;
      Future<void> worker() async {
        while (!_disposed &&
            generation == _generation &&
            next < pending.length) {
          final entry = pending[next++];
          try {
            final bytes = await downloader.download(entry.value);
            if (_disposed || generation != _generation) return;
            final logo = DepotHoldingLogo(
              key: entry.key,
              sourceUrl: entry.value,
              bytes: bytes,
              fetchedAt: DateTime.now(),
            );
            await _store.saveHoldingLogo(logo);
            if (_disposed || generation != _generation) return;
            _logos[entry.key] = logo;
          } catch (e) {
            _failed++;
            errorLog('[DepotLogoState] Logo download failed: $e');
          }
          _completed++;
          _notify();
        }
      }

      await Future.wait([
        for (var i = 0; i < 2 && i < pending.length; i++) worker(),
      ]);
    } catch (e) {
      _loadFailed = true;
      errorLog('[DepotLogoState] Downloading logos failed: $e');
    } finally {
      _isFetching = false;
      _notify();
    }
  }

  void reset() {
    reduceCache();
    _notify();
  }

  void reduceCache() {
    _generation++;
    _logos.clear();
    _loading = null;
    _loadFailed = false;
    _failed = 0;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
