import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'chiptune_archive.dart';
import 'chiptune_colors.dart';
import 'chiptune_sync_delegate.dart';
import 'config.dart';
import 'engine/chiptune_player.dart';
import 'engine/parser.dart';
import 'widgets/chiptune_archive_panel.dart';
import 'widgets/chiptune_channel_activity.dart';
import 'widgets/chiptune_module_info.dart';
import 'widgets/chiptune_sample_list.dart';
import 'widgets/chiptune_seek_bar.dart';
import 'widgets/chiptune_transport_bar.dart';
import 'widgets/chiptune_visualizer.dart';

class ChiptunePage extends StatefulWidget {
  final SharedFile? sharedFile;
  const ChiptunePage({super.key, this.sharedFile});

  @override
  State<ChiptunePage> createState() => _ChiptunePageState();
}

class _ChiptunePageState extends State<ChiptunePage> with DisposeCleanup {
  static const List<String> _extensions = ['mod', 'xm', 'it', 's3m'];

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
      if (_extensions.any((e) => lower.endsWith('.$e'))) {
        _loadSharedFile(file);
      }
    });
    onDispose(sub.cancel);
  }

  Future<void> _restoreSettings() async {
    final db = DatabaseService.instance;
    final vol = await db.getSetting(ChiptuneArchive.toolId, 'volume');
    final loop = await db.getSetting(ChiptuneArchive.toolId, 'looping');
    if (!mounted) return;
    setState(() {
      _volume = double.tryParse(vol ?? '') ?? 0.7;
      _looping = loop == '1';
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

  Future<void> _loadSharedFile(SharedFile file) async {
    try {
      final bytes = await File(file.path).readAsBytes();
      await _loadBytes(bytes, file.name);
      await _player.play();
    } catch (e) {
      if (mounted) _showSnack('Failed to open shared file: $e');
    }
  }

  void _clear() {
    _player.stop();
    setState(() {
      _currentBytes = null;
      _currentFileName = '';
      _currentFormat = '';
      _currentArchiveId = null;
    });
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
    final hasModule = _player.module != null;
    return ToolLayout(
      title: ChiptuneTool.config.name,
      actions: [
        if (hasModule)
          IconButton(
            tooltip: 'Load another',
            icon: const Icon(Icons.folder_open),
            onPressed: () => _clear(),
          ),
      ],
      child: hasModule ? _buildPlayer() : _buildDropzone(),
    );
  }

  Widget _buildDropzone() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: FileDropZone(
              allowedExtensions: _extensions,
              typeLabel: 'Tracker module',
              accentColor: ChiptuneColors.accent,
              icon: Icons.music_note_outlined,
              title: 'Drop a tracker module',
              subtitle: 'MOD · XM · IT files',
              onFileSelected: _onFilePicked,
            ),
          ),
          if (_archive.isNotEmpty) ...[
            const SizedBox(height: 12),
            _archivePanel(),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    final mod = _player.module!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AspectRatio(
          aspectRatio: 16 / 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: const Color(0xFF120E20),
              child: ValueListenableBuilder(
                valueListenable: _player.state,
                builder: (_, state, _) => ChiptuneVisualizer(
                  active: state == ChiptunePlaybackState.playing,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ChiptuneModuleInfo(module: mod),
        const SizedBox(height: 8),
        ValueListenableBuilder(
          valueListenable: _player.position,
          builder: (_, position, _) => ValueListenableBuilder(
            valueListenable: _player.elapsed,
            builder: (_, elapsed, _) => ChiptuneSeekBar(
              position: position,
              elapsed: elapsed,
              rowsPerPattern: mod.rowsPerPattern,
              totalRows: _player.totalRows,
              onSeekFraction: (f) {
                final targetRow = (f * _player.totalRows).floor();
                final order = (targetRow / mod.rowsPerPattern).floor();
                final row = targetRow % mod.rowsPerPattern;
                _player.seek(order, row);
              },
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: _player.state,
          builder: (_, state, _) => ChiptuneTransportBar(
            isPlaying: state == ChiptunePlaybackState.playing,
            looping: _looping,
            volume: _volume,
            onPlayPause: _playPause,
            onStop: _player.stop,
            onLoopChanged: _setLooping,
            onVolumeChanged: _setVolume,
          ),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder(
          valueListenable: _player.channelActivity,
          builder: (_, active, _) => ChiptuneChannelActivity(active: active),
        ),
        const SizedBox(height: 8),
        ChiptuneSampleList(module: mod),
        const Divider(height: 24),
        _archivePanel(),
      ],
    );
  }

  Widget _archivePanel() {
    return ChiptuneArchivePanel(
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
  }
}
