import 'dart:io';
import 'package:tool_lab/helpers/debug_log.dart';
import 'dart:isolate';
import 'dart:typed_data';

import 'engine/mixer.dart';
import 'engine/module.dart';

import 'package:file_selector/file_selector.dart'
    show XFile, XTypeGroup, openFiles, getDirectoryPath;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/mime_type_helper.dart';
import 'package:tool_lab/helpers/system_audio_player.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'chiptune_archive.dart';
import 'chiptune_state.dart';
import 'chiptune_sync_delegate.dart';
import 'collection_service.dart';
import 'config.dart';
import 'engine/chiptune_player.dart';
import 'engine/parser.dart';
import 'modarchive_service.dart';
import 'widgets/chiptune_archive_panel.dart';
import 'widgets/chiptune_audio_view.dart';
import 'widgets/chiptune_empty_state.dart';
import 'widgets/chiptune_player_view.dart';
import 'widgets/chiptune_playlist_panel.dart';
import 'widgets/chiptune_tweaks_dialog.dart';
import 'widgets/chiptune_random_button.dart';
import 'widgets/modarchive_fetch_dialog.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class ChiptunePage extends StatefulWidget {
  final SharedFile? sharedFile;
  const ChiptunePage({super.key, this.sharedFile});

  @override
  State<ChiptunePage> createState() => _ChiptunePageState();
}

class _ChiptunePageState extends State<ChiptunePage>
    with DisposeCleanup, WidgetsBindingObserver {
  /// How many random tracks to fetch-and-try before giving up when modules keep
  /// failing to load. Bounds the skip loop so a run of bad modules can't spin
  /// forever.
  static const int _maxRandomLoadAttempts = 5;

  /// Extensions decoded natively by SoLoud (not tracker modules). Everything
  /// else in [ChiptuneTool.config.fileExtensions] goes through the module parser.
  static const List<String> _nativeAudioExtensions = [
    'wav',
    'mp3',
    'ogg',
    'flac',
  ];

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

  final ChiptunePlayer _player = ChiptunePlayer();
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
  bool _syncing = false;
  bool _backendAvailable = false;
  bool _appInForeground = true;

  /// True while an externally-opened/shared file is being read + decoded, so the
  /// view shows a spinner instead of briefly flashing the empty upload zone.
  bool _openingSharedFile = false;

  /// The Android output-capture permission is asked for at most once per visit —
  /// it only enables the visualizer during system-codec playback, so a denial
  /// must not re-prompt on every track.
  bool _capturePermissionAsked = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<ChiptuneState>();
    _openingSharedFile = widget.sharedFile != null;
    WidgetsBinding.instance.addObserver(this);
    onDispose(() => WidgetsBinding.instance.removeObserver(this));
    onDispose(_player.dispose);

    _player.onEnded = _onPlaybackEnded;
    _player.onNext = _onPlaybackNext;
    _player.onNearEnd = _onNearEnd;
    _player.onPlaybackError = (error) {
      if (mounted) {
        _showSnack(AppLocalizations.of(context).chipAudioPlaybackFailed(error));
      }
    };
    // Hold the wakelock + foreground service across a song-end when another
    // track will auto-follow, so the (possibly background) fetch is not killed.
    _player.shouldKeepPlaybackAlive = () =>
        !settings.looping &&
        (_randomMode ||
            _serverRandomMode ||
            _nextPlaylistIndex() != null ||
            _nextArchivedId() != null);

    settings.addListener(_applySettingsToPlayer);
    onDispose(() => settings.removeListener(_applySettingsToPlayer));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Restore settings first (fast db reads for volume/looping), then load the
      // opened file so playback starts ASAP. The archive + auto-sync (which can
      // do slow network calls) run afterwards — they only populate the local
      // files panel and must not delay playback of a file the user just opened.
      await context.read<ChiptuneState>().restore();
      _applySettingsToPlayer();
      if (widget.sharedFile != null) {
        await _loadSharedFile(widget.sharedFile!);
      }
      await _loadArchive();
      await _maybeAutoSync();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context);
    _player.notificationTitle = l10n.chipNotificationTitle;
    _player.notificationText = l10n.chipNotificationText;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool active = state == AppLifecycleState.resumed;
    _player.setUiUpdatesEnabled(active);
    if (!mounted) return;
    if (_appInForeground != active) {
      setState(() => _appInForeground = active);
    }
  }

  void _applySettingsToPlayer() {
    final s = context.read<ChiptuneState>();
    _player.setVolume(s.volume);
    _player.setStereoWidth(s.stereoWidth);
    _player.setInterpolation(s.interpolation);
    _player.setPreAmp(s.preAmp);
    _player.setAmigaFilter(s.amigaFilter);
    _player.setRampStep(s.rampStep);
    _player.setModSeparation(s.modSeparation);
    _player.setLooping(s.looping);
    _player.setInitialDeviceId(s.outputDeviceId);
  }

  // ---- File loading ----

  /// Parses [bytes] and hands the module to the player. Returns `false` when the
  /// module cannot be parsed (unplayable), so auto-advance paths can skip to the
  /// next track instead of silently replaying the previous one. When
  /// [notifyOnError] is false the parse-failure snackbar is suppressed — used by
  /// retry/skip loops that only report once all candidates fail.
  Future<bool> _loadBytes(
    Uint8List bytes,
    String fileName, {
    bool notifyOnError = true,
  }) async {
    try {
      final String format;
      if (_isNativeAudioName(fileName)) {
        await _player.loadAudio(bytes, fileName);
        format = _extensionOf(fileName).toUpperCase();
        _player.notificationTitle = fileName;
      } else {
        final mod = parseModule(bytes);
        _player.loadModule(mod);
        format = mod.type;
        _player.notificationTitle = mod.title.isNotEmpty ? mod.title : fileName;
      }
      _player.notificationText = ChiptunePlayer.formatTime(
        Duration.zero,
        _player.totalDuration,
      );
      if (!mounted) return true;
      setState(() {
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
      });
      return true;
    } catch (e) {
      if (mounted && notifyOnError) {
        _showSnack(
          AppLocalizations.of(context).chipFailedToParseModule(e.toString()),
        );
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
    if (context.read<ChiptuneState>().visualizerEnabled &&
        !_capturePermissionAsked) {
      _capturePermissionAsked = true;
      await SystemAudioPlayer.instance.requestCapturePermission();
    }
    if (!await _player.loadSystemAudio(path, fileName)) return false;
    _player.notificationTitle = fileName;
    _player.notificationText = ChiptunePlayer.formatTime(
      Duration.zero,
      _player.totalDuration,
    );
    if (!mounted) return true;
    setState(() {
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
    });
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
    if (mounted) {
      _showSnack(
        AppLocalizations.of(context).chipUnsupportedAudioOpenedInternally,
      );
    }
    return true;
  }

  /// Single load entry point: one or many files become the playlist and play
  /// from the first supported entry. A single selection is just a length-1
  /// playlist (no queue panel).
  Future<void> _startFiles(List<XFile> files, String emptyMessage) async {
    final supported = files.where((f) {
      final lower = f.name.toLowerCase();
      return ChiptuneTool.config.fileExtensions.any(
        (e) => lower.endsWith('.$e'),
      );
    }).toList();
    if (supported.isEmpty) {
      _showSnack(emptyMessage);
      return;
    }
    setState(() {
      _playlist = supported;
      _playlistIndex = -1;
    });
    await _playPlaylistIndex(0);
  }

  Future<void> _pickFiles() async {
    final l10n = AppLocalizations.of(context);
    final files = await openFiles(
      acceptedTypeGroups: [
        XTypeGroup(
          label: l10n.chipEmptyTypeLabel,
          extensions: Platform.isAndroid
              ? null
              : ChiptuneTool.config.fileExtensions,
          mimeTypes: Platform.isAndroid ? const ['audio/*'] : null,
        ),
      ],
    );
    if (files.isEmpty || !mounted) return;
    await _startFiles(files, l10n.chipPlaylistNoSupported);
  }

  /// Directory picking + local enumeration only works on desktop; Android hands
  /// back a SAF tree URI that dart:io cannot list.
  bool get _folderPickSupported => Platform.isWindows || Platform.isLinux;

  Future<void> _pickFolder() async {
    final l10n = AppLocalizations.of(context);
    final dir = await getDirectoryPath();
    if (dir == null || !mounted) return;
    List<XFile> files;
    try {
      final entries = await Directory(dir).list(followLinks: false).toList();
      files = entries.whereType<File>().map((f) => XFile(f.path)).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (e) {
      if (mounted) _showSnack(l10n.chipFolderEmpty);
      return;
    }
    await _startFiles(files, l10n.chipFolderEmpty);
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
    if (!mounted) return;
    if (loaded) {
      setState(() => _playlistIndex = index);
      await _player.play();
      return;
    }
    // Unplayable entry — skip to the next one instead of stalling on it.
    final next = index + 1;
    if (next < _playlist.length) {
      await _playPlaylistIndex(next);
    } else {
      _showSnack(AppLocalizations.of(context).chipPlaylistNoSupported);
    }
  }

  Future<void> _loadSharedFile(SharedFile file) async {
    if (mounted && !_openingSharedFile) {
      setState(() => _openingSharedFile = true);
    }
    try {
      if (!_isNativeAudioName(file.name) && _isAudioName(file.name)) {
        if (await _loadSystemAudio(file.path, file.name)) {
          await _player.play();
          return;
        }
        final mimeType = file.mimeType == 'application/octet-stream'
            ? MimeTypeHelper.getMimeType(file.name)
            : file.mimeType;
        if (await _openExternally(file.path, mimeType)) return;
        if (mounted) {
          _showSnack(AppLocalizations.of(context).chipUnsupportedAudioFormat);
        }
        return;
      }
      final bytes = await File(file.path).readAsBytes();
      await _loadBytes(bytes, file.name);
      await _player.play();
    } catch (e) {
      if (mounted) {
        _showSnack(
          AppLocalizations.of(context).chipFailedToOpenSharedFile(e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _openingSharedFile = false);
    }
  }

  // ---- Transport ----

  Future<void> _playPause() async {
    if (_player.isPlaying) {
      _player.pause();
    } else {
      await _player.play();
    }
  }

  void _setVolume(double v) => context.read<ChiptuneState>().setVolume(v);

  void _setStereoWidth(double v) =>
      context.read<ChiptuneState>().setStereoWidth(v);

  void _setInterpolation(ChiptuneInterpolation mode) =>
      context.read<ChiptuneState>().setInterpolation(mode);

  void _setPreAmp(double v) => context.read<ChiptuneState>().setPreAmp(v);

  void _setAmigaFilter(ChiptuneAmigaFilter mode) =>
      context.read<ChiptuneState>().setAmigaFilter(mode);

  void _setRampStep(double v) => context.read<ChiptuneState>().setRampStep(v);

  void _setModSeparation(double v) =>
      context.read<ChiptuneState>().setModSeparation(v);

  void _setLooping(bool v) => context.read<ChiptuneState>().setLooping(v);

  void _setVisualizerEnabled(bool v) =>
      context.read<ChiptuneState>().setVisualizerEnabled(v);

  void _setVizId(String id) =>
      context.read<ChiptuneState>().setCurrentVizId(id);

  void _setOutputDevice(PlaybackDevice? device) {
    context.read<ChiptuneState>().setOutputDeviceId(device?.id);
    _player.setOutputDevice(device);
  }

  void _showDeviceSelectionDialog(List<PlaybackDevice> devices) {
    final l10n = AppLocalizations.of(context);
    final settings = context.read<ChiptuneState>();
    final selectedId = settings.outputDeviceId;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return ResponsiveAlertDialog(
              title: Text(l10n.chipSelectOutputDevice),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    final isSelected =
                        (selectedId == null && device.isDefault) ||
                        (selectedId == device.id);
                    return ListTile(
                      leading: Icon(
                        device.isDefault
                            ? Icons.speaker_outlined
                            : Icons.volume_up_outlined,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(
                        device.isDefault
                            ? '${device.name} (${l10n.chipDefaultDevice})'
                            : device.name,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        setDialogState(() {
                          settings.setOutputDeviceId(
                            device.isDefault ? null : device.id,
                          );
                        });
                        _setOutputDevice(device.isDefault ? null : device);
                        Navigator.of(context).pop();
                        _showSnack(l10n.chipOutputDeviceChanged(device.name));
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonBack),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTweaksDialog() {
    final s = context.read<ChiptuneState>();
    ChiptuneTweaksDialog.show(
      context,
      interpolation: s.interpolation,
      stereoWidth: s.stereoWidth,
      preAmp: s.preAmp,
      amigaFilter: s.amigaFilter,
      rampStep: s.rampStep,
      modSeparation: s.modSeparation,
      onInterpolationChanged: _setInterpolation,
      onStereoWidthChanged: _setStereoWidth,
      onPreAmpChanged: _setPreAmp,
      onAmigaFilterChanged: _setAmigaFilter,
      onRampStepChanged: _setRampStep,
      onModSeparationChanged: _setModSeparation,
    );
  }

  VoidCallback? _nextButtonAction() {
    if (_randomMode) return _skipRandom;
    if (_serverRandomMode) {
      return () => _advanceServerRandom(stopOnFailure: false);
    }
    final nextPlaylist = _nextPlaylistIndex();
    if (nextPlaylist != null) return () => _playPlaylistIndex(nextPlaylist);
    final next = _nextArchivedId();
    if (next != null) return () => _playArchived(next);
    return null;
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
    if (context.read<ChiptuneState>().looping) return;
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
    if (next != null) _playArchived(next);
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
    if (next != null) _playArchived(next);
  }

  // ---- Random (The Mod Archive) ----

  void _onNearEnd() {
    if (context.read<ChiptuneState>().looping) return;
    if (_randomMode) {
      _startPrefetch();
    } else if (_serverRandomMode) {
      _startServerPrefetch();
    }
  }

  void _startPrefetch() {
    if (_prefetch != null) return;
    setState(() => _fetchingNext = true);
    final future = _fetchRandomOrNull();
    _prefetch = future;
    future.whenComplete(() {
      if (mounted) setState(() => _fetchingNext = false);
    });
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
    setState(() => _fetchingNext = true);
    try {
      final pending = _prefetch;
      _prefetch = null;
      for (int attempt = 0; attempt < _maxRandomLoadAttempts; attempt++) {
        ModArchiveTune? tune = attempt == 0 && pending != null
            ? await pending
            : null;
        tune ??= await _modArchive.fetchRandom();
        if (!mounted) return;
        if (await _playRandomTune(tune)) return;
      }
      if (stopOnFailure) _player.stop();
    } catch (_) {
      if (stopOnFailure) _player.stop();
    } finally {
      _advancing = false;
      if (mounted) setState(() => _fetchingNext = false);
    }
  }

  Future<void> _startRandom() async {
    final tune = await ModArchiveFetchDialog.show(context, _modArchive);
    if (tune == null || !mounted) return;
    if (!await _playRandomTune(tune) && mounted) {
      _showSnack(
        AppLocalizations.of(context).chipFailedToParseModule(tune.fileName),
      );
    }
  }

  /// Manual skip via the transport next button — keeps the fetch-progress modal.
  Future<void> _skipRandom() async {
    final tune = await ModArchiveFetchDialog.show(
      context,
      _modArchive,
      autoPlay: true,
    );
    if (tune == null || !mounted) return;
    if (!await _playRandomTune(tune) && mounted) {
      _showSnack(
        AppLocalizations.of(context).chipFailedToParseModule(tune.fileName),
      );
    }
  }

  /// Returns `true` when the tune loaded and playback started, `false` when the
  /// module was unplayable (so callers can try the next one).
  Future<bool> _playRandomTune(ModArchiveTune tune) async {
    if (!await _loadBytes(tune.bytes, tune.fileName, notifyOnError: false)) {
      return false;
    }
    if (!mounted) return false;
    setState(() {
      _randomMode = true;
      _currentTune = tune;
    });
    await _player.play();
    return true;
  }

  // ---- Random (my server collection) ----

  Future<void> _startServerRandom() =>
      _advanceServerRandom(stopOnFailure: false);

  void _startServerPrefetch() {
    if (_serverPrefetch != null) return;
    setState(() => _fetchingNext = true);
    final future = _fetchServerRandomOrNull();
    _serverPrefetch = future;
    future.whenComplete(() {
      if (mounted) setState(() => _fetchingNext = false);
    });
  }

  Future<CollectionTune?> _fetchServerRandomOrNull() async {
    final baseUrl = context.read<AppState>().syncServerUrl;
    try {
      return await _collection.fetchRandom(baseUrl);
    } catch (_) {
      return null;
    }
  }

  /// Fetches and plays a random module from the user's backend collection.
  /// Uses prefetched tune when available for gapless transition.
  Future<void> _advanceServerRandom({required bool stopOnFailure}) async {
    if (_advancing) return;
    _advancing = true;
    setState(() => _fetchingNext = true);
    final baseUrl = context.read<AppState>().syncServerUrl;
    try {
      final pending = _serverPrefetch;
      _serverPrefetch = null;
      for (int attempt = 0; attempt < _maxRandomLoadAttempts; attempt++) {
        CollectionTune? tune = attempt == 0 && pending != null
            ? await pending
            : null;
        tune ??= await _collection.fetchRandom(baseUrl);
        if (!mounted) return;
        // Skip unplayable picks and fetch another instead of stalling on them.
        if (!await _loadBytes(
          tune.bytes,
          tune.fileName,
          notifyOnError: false,
        )) {
          continue;
        }
        if (!mounted) return;
        final mod = _player.module;
        if (mod != null && mod.title.isNotEmpty) {
          tune = CollectionTune(
            id: tune.id,
            fileName: tune.fileName,
            format: tune.format,
            title: mod.title,
            bytes: tune.bytes,
          );
        }
        setState(() {
          _serverRandomMode = true;
          _currentServerTune = tune;
        });
        await _player.play();
        return;
      }
      // Every attempt produced an unplayable module.
      if (mounted && stopOnFailure) _player.stop();
    } catch (e) {
      if (mounted) {
        _showSnack(
          AppLocalizations.of(context).chipServerRandomFailed(e.toString()),
        );
        if (stopOnFailure) _player.stop();
      }
    } finally {
      _advancing = false;
      if (mounted) setState(() => _fetchingNext = false);
    }
  }

  // ---- Archive ----

  Future<void> _loadArchive() async {
    final repaired = await ChiptuneArchive.instance.repairEmptyRecords();
    if (repaired > 0) {
      errorLog('[ChiptunePage] Repaired $repaired empty archive records');
      if (mounted) await _maybeAutoSync();
    }
    final modules = await ChiptuneArchive.instance.getModules();
    if (!mounted) return;
    setState(() => _archive = modules);
  }

  Future<void> _saveCurrent() async {
    final bytes = _currentBytes;
    if (bytes == null) return;
    // Native audio files have no module metadata; fall back to the file name and
    // zero channels (the archive is format-agnostic — it only stores bytes).
    final mod = _player.module;
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
    if (!mounted) return;
    _showSnack(
      ok
          ? AppLocalizations.of(context).chipModuleArchived
          : AppLocalizations.of(context).chipAlreadyInArchive,
    );
    if (ok) {
      await _loadArchive();
      await _maybeAutoSync();
    }
  }

  Future<void> _playArchived(String id) async {
    final bytes = await ChiptuneArchive.instance.getBytes(id);
    if (bytes == null) {
      if (mounted) {
        _showSnack(AppLocalizations.of(context).chipArchivedModuleNotFound);
      }
      return;
    }
    final entry = _archive.firstWhere((m) => m.id == id);
    if (!await _loadBytes(bytes, entry.fileName, notifyOnError: false)) {
      // Unplayable archived module — advance to the next entry if there is one.
      if (!mounted) return;
      final idx = _archive.indexWhere((m) => m.id == id);
      if (idx >= 0 && idx + 1 < _archive.length) {
        await _playArchived(_archive[idx + 1].id);
      } else {
        _showSnack(
          AppLocalizations.of(context).chipFailedToParseModule(entry.fileName),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _currentArchiveId = id);
    await _player.play();
  }

  Future<void> _downloadArchived(String id) async {
    final idx = _archive.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    final entry = _archive[idx];
    final bytes = await ChiptuneArchive.instance.getBytes(id);
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        _showSnack(AppLocalizations.of(context).chipModuleDataNotAvailable);
      }
      return;
    }
    final ext = entry.fileName.contains('.')
        ? entry.fileName.split('.').last
        : entry.format.toLowerCase();
    final name = '${entry.title.isEmpty ? entry.fileName : entry.title}.$ext';
    if (!mounted) return;
    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: name,
      bytes: bytes,
    );
  }

  Future<void> _deleteArchived(String id) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.chipDeleteModuleTitle,
      message: l10n.chipDeleteModuleMessage,
      confirmLabel: l10n.commonDelete,
    );
    if (confirmed != true) return;
    await ChiptuneArchive.instance.deleteModule(id);
    if (_currentArchiveId == id) _currentArchiveId = null;
    await _loadArchive();
    await _maybeAutoSync();
  }

  // ---- Sync ----

  Future<void> _maybeAutoSync() async {
    final appState = context.read<AppState>();
    if (!appState.syncEnabled || appState.syncServerUrl.isEmpty) {
      setState(() => _backendAvailable = false);
      return;
    }
    await _checkBackend();
    if (!_backendAvailable) return;
    await _runSync(showFeedback: false);
  }

  Future<void> _checkBackend() async {
    final appState = context.read<AppState>();
    final ok = await SyncService.isBackendAvailable(appState.syncServerUrl);
    if (mounted) setState(() => _backendAvailable = ok);
  }

  Future<void> _runSync({bool showFeedback = true}) async {
    final appState = context.read<AppState>();
    if (!appState.syncEnabled || appState.syncServerUrl.isEmpty) return;
    if (!appState.isToolSyncEnabled(ChiptuneTool.config.id)) {
      if (showFeedback) {
        _showSnack(AppLocalizations.of(context).coreSyncToolDisabled);
      }
      return;
    }
    setState(() => _syncing = true);
    try {
      final result = await appState.syncWithBackend([ChiptuneSyncDelegate()]);
      await _loadArchive();
      if (mounted && showFeedback) {
        _showSnack(
          AppLocalizations.of(
            context,
          ).chipSyncedResult(result?['pulled'] ?? 0, result?['pushed'] ?? 0),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack(AppLocalizations.of(context).chipSyncFailed(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  ChiptuneArchivePanel _buildArchivePanel() => ChiptuneArchivePanel(
    modules: _archive,
    canSave: _currentBytes != null,
    syncing: _syncing,
    showSync: _backendAvailable,
    currentId: _currentArchiveId,
    inScrollableParent: true,
    onSave: _saveCurrent,
    onSync: _runSync,
    onPlay: _playArchived,
    onDownload: _downloadArchived,
    onDelete: _deleteArchived,
  );

  Widget? _buildPlaylistPanel() {
    if (_playlistIndex < 0 || _playlist.length <= 1) return null;
    return ChiptunePlaylistPanel(
      fileNames: [for (final f in _playlist) f.name],
      currentIndex: _playlistIndex,
      inScrollableParent: true,
      onPlay: _playPlaylistIndex,
    );
  }

  void _seekFraction(double f) {
    final total = _player.totalDuration.inMilliseconds;
    _player.seekTo(Duration(milliseconds: (f.clamp(0.0, 1.0) * total).round()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<ChiptuneState>();
    final module = _player.module;
    final hasPlayable = _player.hasAudio;
    final isPlainAudio = _player.isPlainAudio;
    final hasServer = context.watch<AppState>().syncServerUrl.trim().isNotEmpty;

    List<PlaybackDevice> devices = [];
    try {
      devices = SoLoud.instance.listPlaybackDevices();
    } catch (_) {}
    final hasMultipleDevices = devices.length > 1;

    final Widget content;
    if (_openingSharedFile && !hasPlayable) {
      content = const Center(child: CircularProgressIndicator());
    } else if (!hasPlayable) {
      content = ChiptuneEmptyState(
        onFilesSelected: (files) =>
            _startFiles(files, l10n.chipPlaylistNoSupported),
        onPickFolder: _folderPickSupported ? _pickFolder : null,
        archivePanel: (_archive.isNotEmpty || _backendAvailable)
            ? _buildArchivePanel()
            : null,
      );
    } else if (isPlainAudio) {
      content = ChiptuneAudioView(
        player: _player,
        fileName: _currentFileName,
        format: _currentFormat,
        looping: settings.looping,
        volume: settings.volume,
        visualizerEnabled: settings.visualizerEnabled,
        animateVisualizer: _appInForeground,
        currentVizId: settings.currentVizId,
        onVizChanged: _setVizId,
        playlistPanel: _buildPlaylistPanel(),
        archivePanel: _buildArchivePanel(),
        onPlayPause: _playPause,
        onStop: _player.stop,
        onNext: _nextButtonAction(),
        nextTooltip: l10n.chipNextTrackTooltip,
        onLoopChanged: _setLooping,
        onVolumeChanged: _setVolume,
        onSeekFraction: _seekFraction,
      );
    } else {
      content = ChiptunePlayerView(
        player: _player,
        module: module!,
        looping: settings.looping,
        volume: settings.volume,
        visualizerEnabled: settings.visualizerEnabled,
        animateVisualizer: _appInForeground,
        currentVizId: settings.currentVizId,
        onVizChanged: _setVizId,
        randomTune: _randomMode ? _currentTune : null,
        serverTune: _serverRandomMode ? _currentServerTune : null,
        playlistPanel: _buildPlaylistPanel(),
        archivePanel: _buildArchivePanel(),
        onPlayPause: _playPause,
        onStop: _player.stop,
        onNext: _nextButtonAction(),
        nextTooltip: (_randomMode || _serverRandomMode)
            ? l10n.chipNextRandomTooltip
            : l10n.chipNextTrackTooltip,
        onLoopChanged: _setLooping,
        onVolumeChanged: _setVolume,
        onSeek: _player.seek,
      );
    }

    return ToolLayout(
      title: ChiptuneTool.config.localizedName(l10n),
      actions: [
        ChiptuneRandomButton(
          busy: _fetchingNext,
          tooltip: hasServer
              ? l10n.chipRandomMenuTooltip
              : l10n.chipRandomTooltip,
          onModArchive: _startRandom,
          onServerCollection: hasServer ? _startServerRandom : null,
          modArchiveLabel: l10n.chipRandomSourceModArchive,
          serverLabel: l10n.chipRandomSourceServer,
        ),
        IconButton(
          tooltip: l10n.chipLoadFiles,
          icon: const Icon(Icons.folder_open),
          onPressed: _pickFiles,
        ),
        if (_folderPickSupported)
          IconButton(
            tooltip: l10n.chipFolderTooltip,
            icon: const Icon(Icons.folder_special_outlined),
            onPressed: _pickFolder,
          ),
        if (hasPlayable || hasMultipleDevices)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) {
              return [
                if (hasPlayable && !isPlainAudio)
                  PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        const Icon(Icons.download_outlined),
                        const SizedBox(width: 8),
                        Text(l10n.chipExportToWav),
                      ],
                    ),
                  ),
                if (hasPlayable)
                  PopupMenuItem(
                    value: 'visualizer',
                    child: Row(
                      children: [
                        Icon(
                          settings.visualizerEnabled
                              ? Icons.equalizer
                              : Icons.equalizer_outlined,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          settings.visualizerEnabled
                              ? l10n.chipHideVisualizer
                              : l10n.chipShowVisualizer,
                        ),
                      ],
                    ),
                  ),
                if (hasPlayable && !isPlainAudio)
                  PopupMenuItem(
                    value: 'tweaks',
                    child: Row(
                      children: [
                        const Icon(Icons.tune),
                        const SizedBox(width: 8),
                        Text(l10n.chipTweaks),
                      ],
                    ),
                  ),
                if (hasMultipleDevices)
                  PopupMenuItem(
                    value: 'device',
                    child: Row(
                      children: [
                        const Icon(Icons.speaker_group_outlined),
                        const SizedBox(width: 8),
                        Text(l10n.chipSelectOutputDevice),
                      ],
                    ),
                  ),
              ];
            },
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportToWav();
                  break;
                case 'visualizer':
                  _setVisualizerEnabled(!settings.visualizerEnabled);
                  break;
                case 'tweaks':
                  _showTweaksDialog();
                  break;
                case 'device':
                  _showDeviceSelectionDialog(devices);
                  break;
              }
            },
          ),
      ],
      child: content,
    );
  }

  Future<void> _exportToWav() async {
    final module = _player.module;
    if (module == null) return;

    final l10n = AppLocalizations.of(context);
    final String cleanTitle = module.title.isNotEmpty
        ? module.title.replaceAll(RegExp(r'[^\w\-\s]'), '').trim()
        : 'track';
    final suggestedName = '$cleanTitle.wav';

    _showSnack(l10n.chipExportingToWav);

    try {
      const sampleRate = 44100;
      final bytes = await Isolate.run(
        () => _renderToWavIsolate(WavExportParams(module, sampleRate)),
      );

      if (!mounted) return;

      final savedPath = await FileSaveHelper.saveFile(
        context: context,
        suggestedName: suggestedName,
        bytes: bytes,
      );

      if (savedPath != null && mounted) {
        _showSnack(l10n.chipExportSuccess);
      }
    } catch (e) {
      if (mounted) {
        _showSnack(l10n.chipExportFailed(e.toString()));
      }
    }
  }
}

class WavExportParams {
  final ModuleFile module;
  final int sampleRate;
  const WavExportParams(this.module, this.sampleRate);
}

Uint8List _renderToWavIsolate(WavExportParams params) {
  final worklet = serializeModuleForWorklet(params.module);
  final mixer = ChiptuneMixer();
  mixer.loadAndPlay(worklet, params.sampleRate, looping: false);

  final List<Int16List> chunks = [];
  int totalFrames = 0;
  const int chunkFrames = 4096;
  final Float32List fBuf = Float32List(chunkFrames * 2);

  // Safeguard: max 20 minutes rendering to prevent infinite loops
  final int maxFrames = params.sampleRate * 60 * 20;

  while (mixer.playing && totalFrames < maxFrames) {
    mixer.render(fBuf, chunkFrames);
    final Int16List iBuf = Int16List(chunkFrames * 2);
    for (int i = 0; i < chunkFrames * 2; i++) {
      final double val = fBuf[i].clamp(-1.0, 1.0);
      iBuf[i] = (val * (val >= 0 ? 32767.0 : 32768.0)).round();
    }
    chunks.add(iBuf);
    totalFrames += chunkFrames;
  }

  final int numBytes = totalFrames * 2 * 2;
  final Uint8List wavBytes = Uint8List(44 + numBytes);
  final ByteData bd = ByteData.view(wavBytes.buffer);

  bd.setUint8(0, 0x52); // R
  bd.setUint8(1, 0x49); // I
  bd.setUint8(2, 0x46); // F
  bd.setUint8(3, 0x46); // F
  bd.setUint32(4, 36 + numBytes, Endian.little);
  bd.setUint8(8, 0x57); // W
  bd.setUint8(9, 0x41); // A
  bd.setUint8(10, 0x56); // V
  bd.setUint8(11, 0x45); // E

  bd.setUint8(12, 0x66); // f
  bd.setUint8(13, 0x6d); // m
  bd.setUint8(14, 0x74); // t
  bd.setUint8(15, 0x20); // space
  bd.setUint32(16, 16, Endian.little);
  bd.setUint16(20, 1, Endian.little);
  bd.setUint16(22, 2, Endian.little);
  bd.setUint32(24, params.sampleRate, Endian.little);
  bd.setUint32(28, params.sampleRate * 4, Endian.little);
  bd.setUint16(32, 4, Endian.little);
  bd.setUint16(34, 16, Endian.little);

  bd.setUint8(36, 0x64); // d
  bd.setUint8(37, 0x61); // a
  bd.setUint8(38, 0x74); // t
  bd.setUint8(39, 0x61); // a
  bd.setUint32(40, numBytes, Endian.little);

  int offset = 44;
  for (final chunk in chunks) {
    for (int i = 0; i < chunk.length; i++) {
      bd.setInt16(offset, chunk[i], Endian.little);
      offset += 2;
    }
  }

  return wavBytes;
}
