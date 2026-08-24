import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'engine/mixer.dart';
import 'engine/module.dart';

import 'package:file_selector/file_selector.dart'
    show XFile, XTypeGroup, openFiles, getDirectoryPath;
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/app_route_observer.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'chiptune_archive.dart';
import 'chiptune_playback_state.dart';
import 'chiptune_state.dart';
import 'chiptune_sync_delegate.dart';
import 'config.dart';
import 'widgets/chiptune_archive_panel.dart';
import 'widgets/chiptune_audio_view.dart';
import 'widgets/chiptune_empty_state.dart';
import 'widgets/chiptune_player_view.dart';
import 'widgets/chiptune_playlist_panel.dart';
import 'widgets/chiptune_random_button.dart';
import 'widgets/chiptune_tweaks_dialog.dart';
import 'widgets/modarchive_fetch_dialog.dart';

/// Thin coordinator over the app-scoped [ChiptunePlaybackState]: all playback,
/// playlist and auto-advance logic lives there and survives leaving this page,
/// so audio keeps running in the background while the user browses other tools.
class ChiptunePage extends StatefulWidget {
  final SharedFile? sharedFile;
  const ChiptunePage({super.key, this.sharedFile});

  @override
  State<ChiptunePage> createState() => _ChiptunePageState();
}

class _ChiptunePageState extends State<ChiptunePage>
    with DisposeCleanup, RouteAware {
  late final ChiptunePlaybackState _playback;

  bool _syncing = false;
  bool _backendAvailable = false;

  @override
  void initState() {
    super.initState();
    _playback = context.read<ChiptunePlaybackState>();
    final settings = context.read<ChiptuneState>();
    _playback.onMessage = (message) =>
        _showSnack(message(AppLocalizations.of(context)));
    _playback.onManualRandomSkip = () => ModArchiveFetchDialog.show(
      context,
      _playback.modArchive,
      autoPlay: true,
    );
    onDispose(() => _playback.onMessage = null);
    onDispose(() => _playback.onManualRandomSkip = null);

    _playback.setUiAttached(true);
    onDispose(() => _playback.setUiAttached(false));
    onDispose(() => appRouteObserver.unsubscribe(this));

    void applySettings() => _playback.applySettings(settings);
    settings.addListener(applySettings);
    onDispose(() => settings.removeListener(applySettings));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Restore settings first (fast db reads for volume/looping), then load the
      // opened file so playback starts ASAP. The archive + auto-sync (which can
      // do slow network calls) run afterwards — they only populate the local
      // files panel and must not delay playback of a file the user just opened.
      await context.read<ChiptuneState>().restore();
      applySettings();
      if (widget.sharedFile != null) {
        await _playback.loadSharedFile(widget.sharedFile!);
      }
      await _playback.reloadArchive();
      await _maybeAutoSync();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context);
    // Idle placeholder only — a loaded track owns the notification title, and
    // playback outlives this page, so re-entering must not overwrite it.
    if (!_playback.player.hasAudio) {
      _playback.player.notificationTitle = l10n.chipNotificationTitle;
      _playback.player.notificationText = l10n.chipNotificationText;
    }
    _playback.syncServerUrl = context.read<AppState>().syncServerUrl;
    final route = ModalRoute.of(context);
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  /// This page stays alive under a pushed screen, so dispose alone would leave
  /// the player in its on-screen mode while the user works elsewhere. A dialog
  /// on top of the page does not count — it still shows the player behind it.
  @override
  void didPushNext() {
    if (popupRouteTracker.popupOnTop) return;
    _playback.setUiAttached(false);
  }

  @override
  void didPopNext() => _playback.setUiAttached(true);

  // ---- Snackbars ----

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- File picking ----

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
    await _playback.startFiles(files);
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
    } catch (_) {
      if (mounted) _showSnack(l10n.chipFolderEmpty);
      return;
    }
    await _playback.startFiles(files);
  }

  // ---- Settings setters ----

  void _setLooping(bool v) => context.read<ChiptuneState>().setLooping(v);

  void _setVisualizerEnabled(bool v) =>
      context.read<ChiptuneState>().setVisualizerEnabled(v);

  void _setVizId(String id) =>
      context.read<ChiptuneState>().setCurrentVizId(id);

  // ---- Random (The Mod Archive) ----

  Future<void> _startRandom() async {
    final tune = await ModArchiveFetchDialog.show(
      context,
      _playback.modArchive,
    );
    if (tune == null || !mounted) return;
    if (!await _playback.playRandomTune(tune) && mounted) {
      _showSnack(
        AppLocalizations.of(context).chipFailedToParseModule(tune.fileName),
      );
    }
  }

  /// Manual skip via the transport next button — keeps the fetch-progress
  /// modal through [ChiptunePlaybackState.onManualRandomSkip].
  VoidCallback? _nextButtonAction() {
    if (!_playback.hasNext) return null;
    return () => _playback.skipNext();
  }

  // ---- Device selection ----

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
                        _playback.player.setOutputDevice(
                          device.isDefault ? null : device,
                        );
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
      onInterpolationChanged: (mode) => s.setInterpolation(mode),
      onStereoWidthChanged: s.setStereoWidth,
      onPreAmpChanged: s.setPreAmp,
      onAmigaFilterChanged: (mode) => s.setAmigaFilter(mode),
      onRampStepChanged: s.setRampStep,
      onModSeparationChanged: s.setModSeparation,
    );
  }

  // ---- Archive ----

  Widget _buildArchivePanel() {
    return ChiptuneArchivePanel(
      modules: _playback.archive,
      canSave: true,
      syncing: _syncing,
      showSync: _backendAvailable,
      currentId: _playback.currentArchiveId,
      inScrollableParent: true,
      onSave: _saveCurrent,
      onSync: _runSync,
      onPlay: _playback.playArchived,
      onDownload: _downloadArchived,
      onDelete: _deleteArchived,
    );
  }

  Widget? _buildPlaylistPanel() {
    if (_playback.playlistIndex < 0 || _playback.playlistCount <= 1) {
      return null;
    }
    return ChiptunePlaylistPanel(
      fileNames: [
        for (int i = 0; i < _playback.playlistCount; i++)
          _playback.playlistNameAt(i),
      ],
      currentIndex: _playback.playlistIndex,
      inScrollableParent: true,
      onPlay: _playback.playPlaylistIndex,
    );
  }

  Future<void> _saveCurrent() async {
    final result = await _playback.saveCurrentToArchive();
    if (!mounted) return;
    switch (result) {
      case ChiptuneArchiveSaveResult.saved:
        _showSnack(AppLocalizations.of(context).chipModuleArchived);
        await _maybeAutoSync();
      case ChiptuneArchiveSaveResult.duplicate:
        _showSnack(AppLocalizations.of(context).chipAlreadyInArchive);
      case ChiptuneArchiveSaveResult.nothing:
        break;
    }
  }

  Future<void> _downloadArchived(String id) async {
    final idx = _playback.archive.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    final entry = _playback.archive[idx];
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
    await _playback.deleteArchived(id);
    if (mounted) await _maybeAutoSync();
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
      await _playback.reloadArchive();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<ChiptuneState>();
    final playback = context.watch<ChiptunePlaybackState>();
    final player = playback.player;
    final module = player.module;
    final hasPlayable = player.hasAudio;
    final isPlainAudio = player.isPlainAudio;
    final hasServer = context.watch<AppState>().syncServerUrl.trim().isNotEmpty;

    List<PlaybackDevice> devices = [];
    try {
      devices = SoLoud.instance.listPlaybackDevices();
    } catch (_) {}
    final hasMultipleDevices = devices.length > 1;

    final Widget content;
    if (playback.loadingSharedFile && !hasPlayable) {
      content = const Center(child: CircularProgressIndicator());
    } else if (!hasPlayable) {
      content = ChiptuneEmptyState(
        onFilesSelected: _playback.startFiles,
        onPickFolder: _folderPickSupported ? _pickFolder : null,
        archivePanel: (playback.archive.isNotEmpty || _backendAvailable)
            ? _buildArchivePanel()
            : null,
      );
    } else if (isPlainAudio) {
      content = ChiptuneAudioView(
        player: player,
        fileName: playback.currentFileName,
        format: playback.currentFormat,
        looping: settings.looping,
        volume: settings.volume,
        visualizerEnabled: settings.visualizerEnabled,
        animateVisualizer: playback.uiActive,
        currentVizId: settings.currentVizId,
        onVizChanged: _setVizId,
        playlistPanel: _buildPlaylistPanel(),
        archivePanel: _buildArchivePanel(),
        onPlayPause: playback.playPause,
        onStop: playback.stop,
        onNext: _nextButtonAction(),
        nextTooltip: l10n.chipNextTrackTooltip,
        onLoopChanged: _setLooping,
        onVolumeChanged: (v) => context.read<ChiptuneState>().setVolume(v),
        onSeekFraction: playback.seekFraction,
      );
    } else {
      content = ChiptunePlayerView(
        player: player,
        module: module!,
        looping: settings.looping,
        volume: settings.volume,
        visualizerEnabled: settings.visualizerEnabled,
        animateVisualizer: playback.uiActive,
        currentVizId: settings.currentVizId,
        onVizChanged: _setVizId,
        randomTune: playback.randomTune,
        serverTune: playback.serverTune,
        playlistPanel: _buildPlaylistPanel(),
        archivePanel: _buildArchivePanel(),
        onPlayPause: playback.playPause,
        onStop: playback.stop,
        onNext: _nextButtonAction(),
        nextTooltip:
            (playback.randomModeActive || playback.serverRandomModeActive)
            ? l10n.chipNextRandomTooltip
            : l10n.chipNextTrackTooltip,
        onLoopChanged: _setLooping,
        onVolumeChanged: (v) => context.read<ChiptuneState>().setVolume(v),
        onSeek: player.seek,
      );
    }

    return ToolLayout(
      title: ChiptuneTool.config.localizedName(l10n),
      actions: [
        ChiptuneRandomButton(
          busy: playback.fetchingNext,
          tooltip: hasServer
              ? l10n.chipRandomMenuTooltip
              : l10n.chipRandomTooltip,
          onModArchive: _startRandom,
          onServerCollection: hasServer ? _playback.startServerRandom : null,
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
    final module = _playback.player.module;
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
    for (int i = 0; i < chunk.length; i++, offset += 2) {
      bd.setInt16(offset, chunk[i], Endian.little);
    }
  }

  return wavBytes;
}
