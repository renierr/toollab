import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/widgets/video_player/video_player_page.dart';

import 'config.dart';

class VideoPlayerToolPage extends StatefulWidget {
  final SharedFile? sharedFile;

  const VideoPlayerToolPage({super.key, this.sharedFile});

  @override
  State<VideoPlayerToolPage> createState() => _VideoPlayerToolPageState();
}

class _VideoPlayerToolPageState extends State<VideoPlayerToolPage> {
  ({Uri source, String name})? _last;

  @override
  void initState() {
    super.initState();
    _playShared();
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

  Future<void> _play(Uri source, String name) async {
    setState(() => _last = (source: source, name: name));
    await VideoPlayerPage.open(context, source: source, title: name);
  }

  // The Android picker hands back a content:// URI, so nothing is copied.
  static Uri _pickedSource(XFile file) => file.path.startsWith('content://')
      ? Uri.parse(file.path)
      : Uri.file(file.path);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final config = VideoPlayerTool.config;
    final last = _last;
    return ToolLayout(
      title: config.localizedName(l10n),
      actions: [
        IconButton(
          tooltip: l10n.videoSettingsTitle,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/video-settings'),
        ),
      ],
      child: FileDropZone(
        onFileSelected: (file) => _play(_pickedSource(file), file.name),
        allowedExtensions: config.fileExtensions,
        allowedMimeTypes: const ['video/*'],
        typeLabel: l10n.videoPlayerToolTypeLabel,
        accentColor: config.accentColor,
        icon: config.icon,
        title: l10n.videoPlayerToolDropTitle,
        subtitle: l10n.videoPlayerToolDropSubtitle,
        androidContentUris: true,
        extraButtons: [
          if (last != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton.icon(
                onPressed: () => _play(last.source, last.name),
                icon: const Icon(Icons.replay),
                label: Text(
                  l10n.videoPlayerToolPlayAgain(last.name),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
