import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'video_player_tool_page.dart';

const List<String> videoPlayerExtensions = [
  'mp4',
  'm4v',
  'mkv',
  'webm',
  'mov',
  'avi',
  '3gp',
  'ts',
  'mts',
  'm2ts',
  'mpg',
  'mpeg',
  'ogv',
  'wmv',
  'flv',
];

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
    shareTarget: ShareTargetConfig(accept: ['video/*']),
    fileExtensions: videoPlayerExtensions,
    acceptsContentUris: true,
    createPage: (sd) => VideoPlayerToolPage(sharedFile: sd?.firstFile),
  );
}
