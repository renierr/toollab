import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart'
    show XFile, XTypeGroup, openFile;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'chiptune_archive.dart';
import 'chiptune_sync_delegate.dart';
import 'config.dart';
import 'engine/chiptune_player.dart';
import 'engine/parser.dart';
import 'modarchive_service.dart';
import 'widgets/chiptune_archive_panel.dart';
import 'widgets/chiptune_empty_state.dart';
import 'widgets/chiptune_player_view.dart';
import 'widgets/modarchive_fetch_dialog.dart';
import 'widgets/visualizations/chiptune_viz_registry.dart';

class ChiptunePage extends StatefulWidget {
  final SharedFile? sharedFile;
  const ChiptunePage({super.key, this.sharedFile});

  @override
  State<ChiptunePage> createState() => _ChiptunePageState();
}

class _ChiptunePageState extends State<ChiptunePage>
    with DisposeCleanup, WidgetsBindingObserver {
  final ChiptunePlayer _player = ChiptunePlayer();
  final ModArchiveService _modArchive = ModArchiveService();

  Uint8List? _currentBytes;
  String _currentFileName = '';
  String _currentFormat = '';
  String? _currentArchiveId;
  bool _randomMode = false;
  ModArchiveTune? _currentTune;

  List<ArchivedModule> _archive = [];
  bool _syncing = false;
  bool _backendAvailable = false;
  double _volume = 0.7;
  bool _looping = false;
  bool _visualizerEnabled = true;
  bool _appInForeground = true;
  String _currentVizId = ChiptuneVizRegistry.defaultId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    onDispose(() => WidgetsBinding.instance.removeObserver(this));
    onDispose(_player.dispose);

    _player.onEnded = _onPlaybackEnded;
    _player.onNext = _onPlaybackNext;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreSettings();
      await _loadArchive();
      await _maybeAutoSync();
      if (widget.sharedFile != null) {
        await _loadSharedFile(widget.sharedFile!);
      }
    });

    final sub = SharingService.instance.onSharedFile.listen((file) {
      final lower = file.name.toLowerCase();
      if (ChiptuneTool.config.fileExtensions.any(
        (e) => lower.endsWith('.$e'),
      )) {
        _loadSharedFile(file);
      }
    });
    onDispose(sub.cancel);
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

  Future<void> _restoreSettings() async {
    final db = DatabaseService.instance;
    final vol = await db.getSetting(ChiptuneArchive.toolId, 'volume');
    final loop = await db.getSetting(ChiptuneArchive.toolId, 'looping');
    final vis = await db.getSetting(ChiptuneArchive.toolId, 'vis_id');
    final visOn = await db.getSetting(ChiptuneArchive.toolId, 'visualizer');
    if (!mounted) return;
    setState(() {
      _volume = double.tryParse(vol ?? '') ?? 0.7;
      _looping = loop == '1';
      _visualizerEnabled = visOn != '0';
      _currentVizId = vis ?? ChiptuneVizRegistry.defaultId;
    });
    _player.setVolume(_volume);
    _player.setLooping(_looping);
  }

  // ---- File loading ----

  Future<void> _loadBytes(Uint8List bytes, String fileName) async {
    try {
      final mod = parseModule(bytes);
      _player.loadModule(mod);
      _player.notificationTitle = mod.title.isNotEmpty ? mod.title : fileName;
      _player.notificationText = ChiptunePlayer.formatTime(
        Duration.zero,
        _player.totalDuration,
      );
      if (!mounted) return;
      setState(() {
        _currentBytes = bytes;
        _currentFileName = fileName;
        _currentFormat = mod.type;
        _currentArchiveId = null;
        _randomMode = false;
        _currentTune = null;
      });
    } catch (e) {
      if (mounted) {
        _showSnack(
          AppLocalizations.of(context).chipFailedToParseModule(e.toString()),
        );
      }
    }
  }

  Future<void> _onFilePicked(XFile file) async {
    final bytes = await file.readAsBytes();
    await _loadBytes(bytes, file.name);
  }

  Future<void> _pickAndLoad() async {
    final l10n = AppLocalizations.of(context);
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: l10n.chipEmptyTypeLabel,
          extensions: ChiptuneTool.config.fileExtensions,
        ),
      ],
    );
    if (file != null) await _onFilePicked(file);
  }

  Future<void> _loadSharedFile(SharedFile file) async {
    try {
      final bytes = await File(file.path).readAsBytes();
      await _loadBytes(bytes, file.name);
      await _player.play();
    } catch (e) {
      if (mounted) {
        _showSnack(
          AppLocalizations.of(context).chipFailedToOpenSharedFile(e.toString()),
        );
      }
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

  void _setVolume(double v) {
    setState(() => _volume = v);
    _player.setVolume(v);
    DatabaseService.instance.setSetting(
      ChiptuneArchive.toolId,
      'volume',
      v.toStringAsFixed(3),
    );
  }

  void _setLooping(bool v) {
    setState(() => _looping = v);
    _player.setLooping(v);
    DatabaseService.instance.setSetting(
      ChiptuneArchive.toolId,
      'looping',
      v ? '1' : '0',
    );
  }

  void _setVisualizerEnabled(bool v) {
    setState(() => _visualizerEnabled = v);
    DatabaseService.instance.setSetting(
      ChiptuneArchive.toolId,
      'visualizer',
      v ? '1' : '0',
    );
  }

  void _setVizId(String id) {
    setState(() => _currentVizId = id);
    DatabaseService.instance.setSetting(ChiptuneArchive.toolId, 'vis_id', id);
  }

  void _onPlaybackEnded() {
    if (_looping) return;
    // Random mode: auto-advance the same way the skip-next button does.
    if (_randomMode) {
      _skipRandom();
      return;
    }
    // 'next' behaviour: advance to the next archived module if one follows.
    if (_currentArchiveId != null) {
      final idx = _archive.indexWhere((m) => m.id == _currentArchiveId);
      if (idx >= 0 && idx + 1 < _archive.length) {
        _playArchived(_archive[idx + 1].id);
      }
    }
  }

  Future<void> _onPlaybackNext() async {
    if (_randomMode) {
      if (_appInForeground) {
        await _skipRandom();
      } else {
        try {
          final tune = await _modArchive.fetchRandom();
          if (!mounted) return;
          await _loadBytes(tune.bytes, tune.fileName);
          await _player.play();
        } catch (_) {
          // Keep current playback or do nothing on background fetch failure
        }
      }
    } else if (_currentArchiveId != null) {
      final idx = _archive.indexWhere((m) => m.id == _currentArchiveId);
      if (idx >= 0 && idx + 1 < _archive.length) {
        _playArchived(_archive[idx + 1].id);
      }
    }
  }

  // ---- Random (The Mod Archive) ----

  /// Opens the fetch modal, and on confirmation plays the tune in random mode.
  Future<void> _startRandom() async {
    final tune = await ModArchiveFetchDialog.show(context, _modArchive);
    if (tune == null || !mounted) return;
    await _playRandomTune(tune);
  }

  /// Skips to the next random tune. Shows a fetch-progress modal that closes
  /// and plays directly once loaded.
  Future<void> _skipRandom() async {
    final tune = await ModArchiveFetchDialog.show(
      context,
      _modArchive,
      autoPlay: true,
    );
    if (tune == null || !mounted) return;
    await _playRandomTune(tune);
  }

  Future<void> _playRandomTune(ModArchiveTune tune) async {
    await _loadBytes(tune.bytes, tune.fileName);
    if (!mounted) return;
    setState(() {
      _randomMode = true;
      _currentTune = tune;
    });
    await _player.play();
    if (mounted) {
      _showSnack(
        AppLocalizations.of(
          context,
        ).chipRandomNowPlaying(tune.title.isEmpty ? tune.fileName : tune.title),
      );
    }
  }

  // ---- Archive ----

  Future<void> _loadArchive() async {
    final repaired = await ChiptuneArchive.instance.repairEmptyRecords();
    if (repaired > 0) {
      debugPrint('[ChiptunePage] Repaired $repaired empty archive records');
      if (mounted) await _maybeAutoSync();
    }
    final modules = await ChiptuneArchive.instance.getModules();
    if (!mounted) return;
    setState(() => _archive = modules);
  }

  Future<void> _saveCurrent() async {
    final bytes = _currentBytes;
    final mod = _player.module;
    if (bytes == null || mod == null) return;
    final ok = await ChiptuneArchive.instance.saveModule(
      bytes: bytes,
      fileName: _currentFileName,
      format: _currentFormat,
      title: mod.title.isEmpty ? _currentFileName : mod.title,
      channels: mod.channels,
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
    await _loadBytes(bytes, entry.fileName);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final module = _player.module;
    final hasModule = module != null;

    return ToolLayout(
      title: ChiptuneTool.config.localizedName(l10n),
      actions: [
        IconButton(
          tooltip: l10n.chipRandomTooltip,
          icon: const Icon(Icons.casino_outlined),
          onPressed: _startRandom,
        ),
        if (hasModule) ...[
          IconButton(
            tooltip: _visualizerEnabled
                ? l10n.chipHideVisualizer
                : l10n.chipShowVisualizer,
            icon: Icon(
              _visualizerEnabled ? Icons.equalizer : Icons.equalizer_outlined,
            ),
            onPressed: () => _setVisualizerEnabled(!_visualizerEnabled),
          ),
          IconButton(
            tooltip: l10n.chipLoadAnother,
            icon: const Icon(Icons.folder_open),
            onPressed: _pickAndLoad,
          ),
        ],
      ],
      child: hasModule
          ? ChiptunePlayerView(
              player: _player,
              module: module,
              looping: _looping,
              volume: _volume,
              visualizerEnabled: _visualizerEnabled && _appInForeground,
              currentVizId: _currentVizId,
              onVizChanged: _setVizId,
              randomTune: _randomMode ? _currentTune : null,
              archivePanel: ChiptuneArchivePanel(
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
              ),
              onPlayPause: _playPause,
              onStop: _player.stop,
              onNext: _randomMode ? _skipRandom : null,
              onLoopChanged: _setLooping,
              onVolumeChanged: _setVolume,
              onSeek: _player.seek,
            )
          : ChiptuneEmptyState(
              onFileSelected: _onFilePicked,
              archivePanel: (_archive.isNotEmpty || _backendAvailable)
                  ? ChiptuneArchivePanel(
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
                    )
                  : null,
            ),
    );
  }
}
