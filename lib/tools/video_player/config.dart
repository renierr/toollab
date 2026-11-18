import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/video_player/video_playlist.dart';

import 'video_player_state.dart';
import 'video_player_tool_page.dart';

class VideoPlayerTool {
  VideoPlayerTool._();

  static ToolModel get config => ToolModel(
    id: 'video-player',
    name: 'Video Player',
    description: 'Play video files with gestures, speed and subtitles',
    icon: Icons.smart_display_outlined,
    route: '/video-player',
    accentColor: AppTheme.accentPurple,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameVideoPlayer,
    descriptionL10n: (l10n) => l10n.toolDescVideoPlayer,
    shareTarget: const ShareTargetConfig(accept: ['video/*']),
    fileExtensions: videoFileExtensions,
    acceptsContentUris: true,
    createPage: (sd) => VideoPlayerToolPage(sharedFile: sd?.firstFile),
    stateProviders: () => [
      ChangeNotifierProvider<VideoPlayerState>(
        create: (_) => VideoPlayerState(),
      ),
    ],
    onClose: (context) => context.read<VideoPlayerState>().release(),
  );
}
