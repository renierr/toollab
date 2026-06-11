import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart'
    show XFile, XTypeGroup, openFile;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'chiptune_archive.dart';
import 'chiptune_sync_delegate.dart';
import 'config.dart';
import 'engine/chiptune_player.dart';
import 'engine/parser.dart';
import 'widgets/chiptune_archive_panel.dart';
import 'widgets/chiptune_empty_state.dart';
import 'widgets/chiptune_player_view.dart';

class ChiptunePage extends StatefulWidget {
  final SharedFile? sharedFile;
  const ChiptunePage({super.key, this.sharedFile});

  @override
  State<ChiptunePage> createState() => _ChiptunePageState();
}

class _ChiptunePageState extends State<ChiptunePage> with DisposeCleanup {
  final ChiptunePlayer _player = ChiptunePlayer();

  Uint8List? _currentBytes;
  String _currentFileName = '';
  String _currentFormat = '';
  String? _currentArchiveId;

  List<ArchivedModule> _archive = [];
  bool _syncing = false;
  bool _backendAvailable = false;
  double _volume = 0.7;
  bool _looping = false;
  bool _visualizerEnabled = true;

  @override
  void initState() {
    super.initState();
    onDispose(_player.dispose);

    _player.onEnded = _onPlaybackEnded;

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
      if (ChiptuneEmptyState.extensions.any((e) => lower.endsWith('.$e'))) {
        _loadSharedFile(file);
      }
    });
    onDispose(sub.cancel);
  }

  Future<void> _restoreSettings() async {
    final db = DatabaseService.instance;
    final vol = await db.getSetting(ChiptuneArchive.toolId, 'volume');
    final loop = await db.getSetting(ChiptuneArchive.toolId, 'looping');
    final vis = await db.getSetting(ChiptuneArchive.toolId, 'visualizer');
    if (!mounted) return;
    setState(() {
      _volume = double.tryParse(vol ?? '') ?? 0.7;
      _looping = loop == '1';
      _visualizerEnabled = vis != '0';
    });
    _player.setVolume(_volume);
    _player.setLooping(_looping);
  }

  // ---- File loading ----

  Future<void> _loadBytes(Uint8List bytes, String fileName) async {
    try {
      final mod = parseModule(bytes);
      _player.loadModule(mod);
      if (!mounted) return;
      setState(() {
        _currentBytes = bytes;
        _currentFileName = fileName;
        _currentFormat = mod.type;
        _currentArchiveId = null;
      });
    } catch (e) {
      if (mounted) _showSnack('Failed to parse module: $e');
    }
  }

  Future<void> _onFilePicked(XFile file) async {
    final bytes = await file.readAsBytes();
    await _loadBytes(bytes, file.name);
  }

  Future<void> _pickAndLoad() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Tracker module',
          extensions: ChiptuneEmptyState.extensions,
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
      if (mounted) _showSnack('Failed to open shared file: $e');
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

  void _onPlaybackEnded() {
    if (_looping) return;
    // 'next' behaviour: advance to the next archived module if one follows.
    if (_currentArchiveId != null) {
      final idx = _archive.indexWhere((m) => m.id == _currentArchiveId);
      if (idx >= 0 && idx + 1 < _archive.length) {
        _playArchived(_archive[idx + 1].id);
      }
    }
  }

  // ---- Archive ----

  Future<void> _loadArchive() async {
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
    _showSnack(ok ? 'Module archived' : 'Already in archive');
    if (ok) {
      await _loadArchive();
      await _maybeAutoSync();
    }
  }

  Future<void> _playArchived(String id) async {
    final bytes = await ChiptuneArchive.instance.getBytes(id);
    if (bytes == null) {
      if (mounted) _showSnack('Archived module not found');
      return;
    }
    final entry = _archive.firstWhere((m) => m.id == id);
    await _loadBytes(bytes, entry.fileName);
    setState(() => _currentArchiveId = id);
    await _player.play();
  }

  Future<void> _deleteArchived(String id) async {
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: 'Delete Module',
      message: 'Remove this module from the archive?',
      confirmLabel: 'Delete',
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
    setState(() => _backendAvailable = true);
    await _runSync();
  }

  Future<void> _runSync() async {
    final appState = context.read<AppState>();
    if (!appState.syncEnabled || appState.syncServerUrl.isEmpty) return;
    setState(() => _syncing = true);
    try {
      await appState.syncWithBackend([ChiptuneSyncDelegate()]);
      await _loadArchive();
    } catch (e) {
      if (mounted) _showSnack('Sync failed: $e');
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
    final module = _player.module;
    final hasModule = module != null;

    final archivePanel = ChiptuneArchivePanel(
      modules: _archive,
      canSave: _currentBytes != null,
      syncing: _syncing,
      showSync: _backendAvailable,
      currentId: _currentArchiveId,
      onSave: _saveCurrent,
      onSync: _runSync,
      onPlay: _playArchived,
      onDelete: _deleteArchived,
    );

    return ToolLayout(
      title: ChiptuneTool.config.name,
      actions: [
        if (hasModule) ...[
          IconButton(
            tooltip: _visualizerEnabled ? 'Hide visualizer' : 'Show visualizer',
            icon: Icon(
              _visualizerEnabled ? Icons.equalizer : Icons.equalizer_outlined,
            ),
            onPressed: () => _setVisualizerEnabled(!_visualizerEnabled),
          ),
          IconButton(
            tooltip: 'Load another',
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
              visualizerEnabled: _visualizerEnabled,
              archivePanel: archivePanel,
              onPlayPause: _playPause,
              onStop: _player.stop,
              onLoopChanged: _setLooping,
              onVolumeChanged: _setVolume,
              onSeek: _player.seek,
            )
          : ChiptuneEmptyState(
              onFileSelected: _onFilePicked,
              archivePanel: _archive.isNotEmpty ? archivePanel : null,
            ),
    );
  }
}
