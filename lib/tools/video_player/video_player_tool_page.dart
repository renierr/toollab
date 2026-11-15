import 'dart:async';

import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/widgets/video_player/video_player_page.dart';
import 'package:tool_lab/widgets/video_player/video_system_channel.dart';

import 'config.dart';
import 'video_history_entry.dart';
import 'video_player_state.dart';
import 'widgets/video_recent_list.dart';

class VideoPlayerToolPage extends StatefulWidget {
  final SharedFile? sharedFile;

  const VideoPlayerToolPage({super.key, this.sharedFile});

  @override
  State<VideoPlayerToolPage> createState() => _VideoPlayerToolPageState();
}

class _VideoPlayerToolPageState extends State<VideoPlayerToolPage>
    with DisposeCleanup {
  @override
  void initState() {
    super.initState();
    _playShared();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<VideoPlayerState>().load();
    });
  }

  @override
  void didUpdateWidget(covariant VideoPlayerToolPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sharedFile != oldWidget.sharedFile) _playShared();
  }

  void _playShared() {
    final shared = widget.sharedFile;
    if (shared == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      // A newer share replaces the video that is still playing.
      Navigator.of(context).popUntil((r) => r == route || r.isFirst);
      _play(shared.uri, shared.name);
    });
  }

  /// A content URI becomes its file when possible; otherwise its read grant
  /// is kept so the recent list can reopen it.
  Future<void> _play(Uri source, String name) async {
    final resolved = await VideoSystemChannel.preferFile(source);
    await VideoSystemChannel.persist(resolved);
    if (!mounted) return;
    await VideoPlayerPage.open(
      context,
      source: resolved,
      title: name,
      resumeStore: context.read<VideoPlayerState>(),
      browseFolder: true,
    );
  }

  void _playRecent(VideoHistoryEntry entry) {
    if (context.read<VideoPlayerState>().isMissing(entry)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).videoPlayerToolMissing),
        ),
      );
      return;
    }
    unawaited(_play(entry.uri, entry.title));
  }

  Future<void> _confirmClear() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.videoPlayerToolClearRecent,
      message: l10n.videoPlayerToolClearRecentMessage,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.commonClear,
      confirmColor: AppTheme.statusRed,
    );
    if (confirmed != true || !mounted) return;
    await context.read<VideoPlayerState>().clear();
  }

  // The Android picker hands back a content:// URI, so nothing is copied.
  static Uri _pickedSource(XFile file) => file.path.startsWith('content://')
      ? Uri.parse(file.path)
      : Uri.file(file.path);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final config = VideoPlayerTool.config;
    final state = context.watch<VideoPlayerState>();
    final entries = state.entries;
    return ToolLayout(
      title: config.localizedName(l10n),
      actions: [
        IconButton(
          tooltip: l10n.videoSettingsTitle,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/video-settings'),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dropZone = FileDropZone(
            onFileSelected: (file) => _play(_pickedSource(file), file.name),
            allowedExtensions: config.fileExtensions,
            allowedMimeTypes: const ['video/*'],
            typeLabel: l10n.videoPlayerToolTypeLabel,
            accentColor: config.accentColor,
            icon: config.icon,
            title: l10n.videoPlayerToolDropTitle,
            subtitle: l10n.videoPlayerToolDropSubtitle,
            androidContentUris: true,
            compact: entries.isNotEmpty && !constraints.canSplit,
          );
          if (entries.isEmpty) return dropZone;
          final recent = VideoRecentList(
            entries: entries,
            isMissing: state.isMissing,
            onPlay: _playRecent,
            onRemove: state.remove,
            onClear: _confirmClear,
          );
          if (constraints.canSplit) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: dropZone),
                const SizedBox(width: 16),
                Expanded(child: recent),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 200, child: dropZone),
              const Divider(height: 1),
              Expanded(child: recent),
            ],
          );
        },
      ),
    );
  }
}
