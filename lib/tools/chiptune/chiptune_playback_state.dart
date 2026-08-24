import 'dart:io';

import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/mime_type_helper.dart';
import 'package:tool_lab/helpers/system_audio_player.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import 'chiptune_archive.dart';
import 'chiptune_state.dart';
import 'collection_service.dart';
import 'config.dart';
import 'engine/chiptune_player.dart';
import 'engine/parser.dart';
import 'modarchive_service.dart';

/// Result of [ChiptunePlaybackState.saveCurrentToArchive].
enum ChiptuneArchiveSaveResult { saved, duplicate, nothing }

/// App-scoped playback session for the chiptune tool. Registered via
/// [ChiptuneTool.config.stateProviders], so it survives leaving the tool page:
/// tracks keep auto-advancing in the background while the user is elsewhere in
/// the app, and returning to the page re-attaches to the running session.
///
/// Owns the shared [ChiptunePlayer.instance] plus everything playback-related
/// (playlist, random modes, prefetch/auto-advance, archive list). The page
/// stays a thin view and only handles dialogs, snacks and sync UI.
class ChiptunePlaybackState extends ChangeNotifier with WidgetsBindingObserver {
  /// Bounds the skip loop so a run of bad modules can't spin forever.
  static const int _maxRandomLoadAttempts = 5;

  /// Extensions decoded natively by SoLoud (not tracker modules). Everything
  /// else in [ChiptuneTool.config.fileExtensions] goes through the module parser.
  static const List<String> _nativeAudioExtensions = [
    'wav',
    'mp3',
    'ogg',
    'flac',
  ];

  /// Set once this app-scoped session exists — i.e. the tool page was opened at
  /// least once. The global mini player gates on it so an app run that never
  /// touches the tool never builds the session or the audio engine.
  static final ValueNotifier<bool> sessionStarted = ValueNotifier(false);

  final ChiptunePlayer player = ChiptunePlayer.instance;
  final ModArchiveService _modArchive = ModArchiveService();
  final ChiptuneCollectionService _collection = ChiptuneCollectionService();

  Uint8List? _currentBytes;
  String _currentFileName = '';
  String _currentFormat = '';
  String? _currentArchiveId;

  /// Transient playlist from a multi-file selection. [_playlistIndex] is the
  /// currently-playing entry, or -1 when not in playlist mode.
  List<XFile> _playlist = [];
  int _playlistIndex = -1;

  bool _randomMode = false;
  ModArchiveTune? _currentTune;

  /// Random playback from the user's own backend collection.
  bool _serverRandomMode = false;
  CollectionTune? _currentServerTune;
  bool _advancing = false;

  /// Prefetch of the next random tune (ModArchive); resolves to null if failed.
  Future<ModArchiveTune?>? _prefetch;

  /// Prefetch of the next random tune (own server); resolves to null if failed.
  Future<CollectionTune?>? _serverPrefetch;
  bool _fetchingNext = false;

  List<ArchivedModule> _archive = [];
  bool _loadingSharedFile = false;

  /// The Android output-capture permission is asked for at most once per app
  /// run — it only enables the visualizer during system-codec playback.
  bool _capturePermissionAsked = false;

  bool _uiActive = true;
  bool _loopingEnabled = false;
  bool _visualizerEnabled = true;
  String _syncServerUrl = '';

  /// Set by the page; lets background logic surface localized messages as
  /// snackbars whenever a page is attached to listen.
  void Function(String Function(AppLocalizations l10n) message)? onMessage;

  /// Set by the page (and any mini-player UI). Lets [skipNext] keep the
  /// ModArchive fetch dialog for manual random skips; without it a manual skip
  /// in random mode falls back to a silent auto-fetch.
  Future<ModArchiveTune?> Function()? onManualRandomSkip;

  ChiptunePlaybackState() {
    WidgetsBinding.instance.addObserver(this);
    // Deferred: creation happens from a page's initState, mid-build for the
    // shell overlay that listens to this.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => sessionStarted.value = true,
    );
    player.onEnded = _onPlaybackEnded;
    player.onNext = _onPlaybackNext;
    player.onNearEnd = _onNearEnd;
    player.onPlaybackError = (error) =>
        _emit((l10n) => l10n.chipAudioPlaybackFailed(error));
    // Hold the wakelock + foreground service across a song-end when another
    // track will auto-follow, so the (possibly slow, background) fetch of the
    // next track is not killed mid-way.
    player.shouldKeepPlaybackAlive = () =>
        _loopingEnabled ||
        _randomMode ||
        _serverRandomMode ||
        _nextPlaylistIndex() != null ||
        _nextArchivedId() != null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sessionStarted.value = false;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool active = state == AppLifecycleState.resumed;
    player.setUiUpdatesEnabled(active);
    if (_uiActive == active) return;
    _uiActive = active;
    notifyListeners();
  }

  void _emit(String Function(AppLocalizations l10n) message) =>
      onMessage?.call(message);

  // ---- Introspection for the UI ----

  Uint8List? get currentBytes => _currentBytes;
  String get currentFileName => _currentFileName;
  String get currentFormat => _currentFormat;
  String? get currentArchiveId => _currentArchiveId;
  bool get loadingSharedFile => _loadingSharedFile;
  bool get fetchingNext => _fetchingNext;
  bool get uiActive => _uiActive;
  List<ArchivedModule> get archive => _archive;
  ModArchiveService get modArchive => _modArchive;
  ModArchiveTune? get randomTune => _randomMode ? _currentTune : null;
  CollectionTune? get serverTune =>
      _serverRandomMode ? _currentServerTune : null;
  int get playlistCount => _playlist.length;
  int get playlistIndex => _playlistIndex;
  String playlistNameAt(int index) => _playlist[index].name;
  bool get randomModeActive => _randomMode;
  bool get serverRandomModeActive => _serverRandomMode;

  set syncServerUrl(String url) => _syncServerUrl = url;

  bool get hasNext =>
      _randomMode ||
      _serverRandomMode ||
      _nextPlaylistIndex() != null ||
      _nextArchivedId() != null;

  int? get nextPlaylistIndex => _nextPlaylistIndex();
  String? get nextArchivedId => _nextArchivedId();

  /// Manual 'next' from any UI (transport bar, notification, mini-player).
  /// Random mode keeps its fetch dialog via [onManualRandomSkip] when set.
  Future<void> skipNext() async {
    if (_randomMode && onManualRandomSkip != null) {
      final tune = await onManualRandomSkip!();
      if (tune == null) return;
      if (!await playRandomTune(tune)) {
        _emit((l10n) => l10n.chipFailedToParseModule(tune.fileName));
      }
      return;
    }
    await _onPlaybackNext();
  }

  static bool _isNativeAudioName(String name) {
    final lower = name.toLowerCase();
    return _nativeAudioExtensions.any((e) => lower.endsWith('.$e'));
  }

  static String _extensionOf(String name) =>
      name.contains('.') ? name.split('.').last : '';

  static bool _isAudioName(String name) {
    const audioExtensions = [
      'aac',
      'aiff',
      'aif',
      'alac',
      'amr',
      'm4a',
      'mka',
      'opus',
      'wma',
    ];
    final lower = name.toLowerCase();
    return _isNativeAudioName(name) ||
        audioExtensions.any((extension) => lower.endsWith('.$extension'));
  }

  /// Set by the page for as long as it is on screen. Off-page the player
  /// deepens its look-ahead, because the PCM pump then competes with the rest
  /// of the app for the main isolate.
  void setUiAttached(bool attached) => player.setUiAttached(attached);

  /// Mirrors persisted settings onto the shared player. Called by the page
  /// whenever [ChiptuneState] changes.
  void applySettings(ChiptuneState s) {
    _loopingEnabled = s.looping;
    _visualizerEnabled = s.visualizerEnabled;
    player.setVolume(s.volume);
    player.setStereoWidth(s.stereoWidth);
    player.setInterpolation(s.interpolation);
    player.setPreAmp(s.preAmp);
    player.setAmigaFilter(s.amigaFilter);
    player.setRampStep(s.rampStep);
    player.setModSeparation(s.modSeparation);
    player.setLooping(s.looping);
    player.setInitialDeviceId(s.outputDeviceId);
  }

  // ---- File loading ----

  /// Parses [bytes] and hands the module to the player. Returns `false` when the
  /// module cannot be parsed (unplayable), so auto-advance paths can skip to the
  /// next track instead of silently replaying the previous one. When
  /// [notifyOnError] is false the parse-failure message is suppressed — used by
  /// retry/skip loops that only report once all candidates fail.
  Future<bool> _loadBytes(
    Uint8List bytes,
    String fileName, {
    bool notifyOnError = true,
  }) async {
    try {
      final String format;
      if (_isNativeAudioName(fileName)) {
        await player.loadAudio(bytes, fileName);
        format = _extensionOf(fileName).toUpperCase();
        player.notificationTitle = fileName;
      } else {
        final mod = parseModule(bytes);
        player.loadModule(mod);
        format = mod.type;
        player.notificationTitle = mod.title.isNotEmpty ? mod.title : fileName;
      }
      player.notificationText = ChiptunePlayer.formatTime(
        Duration.zero,
        player.totalDuration,
      );
      _currentBytes = bytes;
      _currentFileName = fileName;
      _currentFormat = format;
      _currentArchiveId = null;
      _playlistIndex = -1;
      _randomMode = false;
      _serverRandomMode = false;
      _currentTune = null;
      _currentServerTune = null;
      _prefetch = null;
      _serverPrefetch = null;
      notifyListeners();
      return true;
    } catch (e) {
      if (notifyOnError) {
        _emit((l10n) => l10n.chipFailedToParseModule(e.toString()));
      }
      return false;
    }
  }

  /// Loads a file no bundled decoder handles (aac, m4a, opus, wma, ...) through
  /// Android's system codecs, keeping ToolLab's own player UI. Returns `false`
  /// when system playback is unavailable or the codecs reject the file, so
  /// callers can fall back to the external player.
  Future<bool> _loadSystemAudio(String path, String fileName) async {
    if (!SystemAudioPlayer.isSupported) return false;
    if (_visualizerEnabled && !_capturePermissionAsked) {
      _capturePermissionAsked = true;
      await SystemAudioPlayer.instance.requestCapturePermission();
    }
    if (!await player.loadSystemAudio(path, fileName)) return false;
    player.notificationTitle = fileName;
    player.notificationText = ChiptunePlayer.formatTime(
      Duration.zero,
      player.totalDuration,
    );
    _currentBytes = null;
    _currentFileName = fileName;
    _currentFormat = _extensionOf(fileName).toUpperCase();
    _currentArchiveId = null;
    _playlistIndex = -1;
    _randomMode = false;
    _serverRandomMode = false;
    _currentTune = null;
    _currentServerTune = null;
    _prefetch = null;
    _serverPrefetch = null;
    notifyListeners();
    return true;
  }

  /// Last resort for a format the in-app decoders cannot handle: hand the file to
  /// the device's media app, which may provide proprietary codecs such as Dolby.
  Future<bool> _openExternally(String path, String mimeType) async {
    try {
      await FileSaveHelper.openFile(path, mimeType);
    } catch (_) {
      return false;
    }
    _emit((l10n) => l10n.chipUnsupportedAudioOpenedInternally);
    return true;
  }

  /// Single load entry point: one or many files become the playlist and play
  /// from the first supported entry.
  Future<void> startFiles(List<XFile> files) async {
    final supported = files.where((f) {
      final lower = f.name.toLowerCase();
      return ChiptuneTool.config.fileExtensions.any(
        (e) => lower.endsWith('.$e'),
      );
    }).toList();
    if (supported.isEmpty) {
      _emit((l10n) => l10n.chipPlaylistNoSupported);
      return;
    }
    _playlist = supported;
    _playlistIndex = -1;
    notifyListeners();
    await _playPlaylistIndex(0);
  }

  Future<void> loadSharedFile(SharedFile file) async {
    _loadingSharedFile = true;
    notifyListeners();
    try {
      if (!_isNativeAudioName(file.name) && _isAudioName(file.name)) {
        if (await _loadSystemAudio(file.path, file.name)) {
          await player.play();
          return;
        }
        final mimeType = file.mimeType == 'application/octet-stream'
            ? MimeTypeHelper.getMimeType(file.name)
            : file.mimeType;
        if (await _openExternally(file.path, mimeType)) return;
        _emit((l10n) => l10n.chipUnsupportedAudioFormat);
        return;
      }
      final bytes = await File(file.path).readAsBytes();
      await _loadBytes(bytes, file.name);
      await player.play();
    } catch (e) {
      _emit((l10n) => l10n.chipFailedToOpenSharedFile(e.toString()));
    } finally {
      _loadingSharedFile = false;
      notifyListeners();
    }
  }

  Future<void> _playPlaylistIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    final file = _playlist[index];
    bool loaded = false;
    if (!_isNativeAudioName(file.name) && _isAudioName(file.name)) {
      loaded = await _loadSystemAudio(file.path, file.name);
      if (!loaded &&
          await _openExternally(
            file.path,
            MimeTypeHelper.getMimeType(file.name),
          )) {
        return;
      }
    } else {
      try {
        final bytes = await file.readAsBytes();
        loaded = await _loadBytes(bytes, file.name, notifyOnError: false);
      } catch (_) {
        loaded = false;
      }
    }
    if (loaded) {
      _playlistIndex = index;
      notifyListeners();
      await player.play();
      return;
    }
    // Unplayable entry — skip to the next one instead of stalling on it.
    final next = index + 1;
    if (next < _playlist.length) {
      await _playPlaylistIndex(next);
    } else {
      _emit((l10n) => l10n.chipPlaylistNoSupported);
    }
  }

  Future<void> playPlaylistIndex(int index) => _playPlaylistIndex(index);

  // ---- Transport ----

  Future<void> playPause() async {
    if (player.isPlaying) {
      player.pause();
    } else {
      await player.play();
    }
  }

  void stop() => player.stop();

  void seekFraction(double f) {
    final total = player.totalDuration.inMilliseconds;
    player.seekTo(Duration(milliseconds: (f.clamp(0.0, 1.0) * total).round()));
  }

  int? _nextPlaylistIndex() {
    if (_playlistIndex < 0) return null;
    final next = _playlistIndex + 1;
    return next < _playlist.length ? next : null;
  }

  String? _nextArchivedId() {
    if (_currentArchiveId == null) return null;
    final idx = _archive.indexWhere((m) => m.id == _currentArchiveId);
    if (idx >= 0 && idx + 1 < _archive.length) {
      return _archive[idx + 1].id;
    }
    return null;
  }

  void _onPlaybackEnded() {
    if (_loopingEnabled) return;
    if (_randomMode) {
      // Nothing left playing to keep, so tear down the session on failure.
      _advanceRandom(stopOnFailure: true);
      return;
    }
    if (_serverRandomMode) {
      _advanceServerRandom(stopOnFailure: true);
      return;
    }
    final nextPlaylist = _nextPlaylistIndex();
    if (nextPlaylist != null) {
      _playPlaylistIndex(nextPlaylist);
      return;
    }
    final next = _nextArchivedId();
    if (next != null) playArchived(next);
  }

  Future<void> _onPlaybackNext() async {
    if (_randomMode) {
      await _advanceRandom(stopOnFailure: false);
      return;
    }
    if (_serverRandomMode) {
      await _advanceServerRandom(stopOnFailure: false);
      return;
    }
    final nextPlaylist = _nextPlaylistIndex();
    if (nextPlaylist != null) {
      await _playPlaylistIndex(nextPlaylist);
      return;
    }
    final next = _nextArchivedId();
    if (next != null) playArchived(next);
  }

  // ---- Random (The Mod Archive) ----

  void _onNearEnd() {
    if (_loopingEnabled) return;
    if (_randomMode) {
      _startPrefetch();
    } else if (_serverRandomMode) {
      _startServerPrefetch();
    }
  }

  void _startPrefetch() {
    if (_prefetch != null) return;
    _setFetching(true);
    final future = _fetchRandomOrNull();
    _prefetch = future;
    future.whenComplete(() => _setFetching(false));
  }

  Future<ModArchiveTune?> _fetchRandomOrNull() async {
    try {
      return await _modArchive.fetchRandom();
    } catch (_) {
      return null;
    }
  }

  /// Uses the prefetched tune when ready, else fetches live, for a gapless jump.
  /// A fetched module that fails to load is skipped and another is pulled, up to
  /// [_maxRandomLoadAttempts] times, so an unplayable random pick advances rather
  /// than stalling.
  Future<void> _advanceRandom({required bool stopOnFailure}) async {
    if (_advancing) return;
    _advancing = true;
    _setFetching(true);
    try {
      final pending = _prefetch;
      _prefetch = null;
      for (int attempt = 0; attempt < _maxRandomLoadAttempts; attempt++) {
        ModArchiveTune? tune = attempt == 0 && pending != null
            ? await pending
            : null;
        tune ??= await _modArchive.fetchRandom();
        if (await playRandomTune(tune)) return;
      }
      if (stopOnFailure) player.stop();
    } catch (_) {
      if (stopOnFailure) player.stop();
    } finally {
      _advancing = false;
      _setFetching(false);
    }
  }

  /// Returns `true` when the tune loaded and playback started, `false` when the
  /// module was unplayable (so callers can report or try the next one).
  Future<bool> playRandomTune(ModArchiveTune tune) async {
    if (!await _loadBytes(tune.bytes, tune.fileName, notifyOnError: false)) {
      return false;
    }
    _randomMode = true;
    _currentTune = tune;
    notifyListeners();
    await player.play();
    return true;
  }

  // ---- Random (my server collection) ----

  Future<void> startServerRandom() =>
      _advanceServerRandom(stopOnFailure: false);

  void _startServerPrefetch() {
    if (_serverPrefetch != null) return;
    _setFetching(true);
    final future = _fetchServerRandomOrNull();
    _serverPrefetch = future;
    future.whenComplete(() => _setFetching(false));
  }

  Future<CollectionTune?> _fetchServerRandomOrNull() async {
    try {
      return await _collection.fetchRandom(_syncServerUrl);
    } catch (_) {
      return null;
    }
  }

  /// Fetches and plays a random module from the user's backend collection.
  /// Uses prefetched tune when available for gapless transition.
  Future<void> _advanceServerRandom({required bool stopOnFailure}) async {
    if (_advancing) return;
    _advancing = true;
    _setFetching(true);
    try {
      final pending = _serverPrefetch;
      _serverPrefetch = null;
      for (int attempt = 0; attempt < _maxRandomLoadAttempts; attempt++) {
        CollectionTune? tune = attempt == 0 && pending != null
            ? await pending
            : null;
        tune ??= await _collection.fetchRandom(_syncServerUrl);
        // Skip unplayable picks and fetch another instead of stalling on them.
        if (!await _loadBytes(
          tune.bytes,
          tune.fileName,
          notifyOnError: false,
        )) {
          continue;
        }
        final mod = player.module;
        if (mod != null && mod.title.isNotEmpty) {
          tune = CollectionTune(
            id: tune.id,
            fileName: tune.fileName,
            format: tune.format,
            title: mod.title,
            bytes: tune.bytes,
          );
        }
        _serverRandomMode = true;
        _currentServerTune = tune;
        notifyListeners();
        await player.play();
        return;
      }
      // Every attempt produced an unplayable module.
      if (stopOnFailure) player.stop();
    } catch (e) {
      _emit((l10n) => l10n.chipServerRandomFailed(e.toString()));
      if (stopOnFailure) player.stop();
    } finally {
      _advancing = false;
      _setFetching(false);
    }
  }

  // ---- Archive ----

  Future<void> reloadArchive() async {
    final repaired = await ChiptuneArchive.instance.repairEmptyRecords();
    if (repaired > 0) {
      errorLog('[ChiptunePlayback] Repaired $repaired empty archive records');
    }
    _archive = await ChiptuneArchive.instance.getModules();
    notifyListeners();
  }

  /// Archives the currently loaded module bytes. Reloads the archive list on
  /// success so auto-advance sees the new entry.
  Future<ChiptuneArchiveSaveResult> saveCurrentToArchive() async {
    final bytes = _currentBytes;
    if (bytes == null) return ChiptuneArchiveSaveResult.nothing;
    // Native audio files have no module metadata; fall back to the file name and
    // zero channels (the archive is format-agnostic — it only stores bytes).
    final mod = player.module;
    final title = mod != null && mod.title.isNotEmpty
        ? mod.title
        : _currentFileName;
    final ok = await ChiptuneArchive.instance.saveModule(
      bytes: bytes,
      fileName: _currentFileName,
      format: _currentFormat,
      title: title,
      channels: mod?.channels ?? 0,
    );
    if (!ok) return ChiptuneArchiveSaveResult.duplicate;
    await reloadArchive();
    return ChiptuneArchiveSaveResult.saved;
  }

  Future<void> playArchived(String id) async {
    final bytes = await ChiptuneArchive.instance.getBytes(id);
    if (bytes == null) {
      _emit((l10n) => l10n.chipArchivedModuleNotFound);
      return;
    }
    final idx = _archive.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    final entry = _archive[idx];
    if (!await _loadBytes(bytes, entry.fileName, notifyOnError: false)) {
      // Unplayable archived module — advance to the next entry if there is one.
      if (idx + 1 < _archive.length) {
        await playArchived(_archive[idx + 1].id);
      } else {
        _emit((l10n) => l10n.chipFailedToParseModule(entry.fileName));
      }
      return;
    }
    _currentArchiveId = id;
    notifyListeners();
    await player.play();
  }

  Future<void> deleteArchived(String id) async {
    await ChiptuneArchive.instance.deleteModule(id);
    if (_currentArchiveId == id) _currentArchiveId = null;
    await reloadArchive();
  }

  void _setFetching(bool value) {
    if (_fetchingNext == value) return;
    _fetchingNext = value;
    notifyListeners();
  }
}
