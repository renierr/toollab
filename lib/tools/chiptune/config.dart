import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'chiptune_page.dart';
import 'chiptune_playback_state.dart';
import 'chiptune_state.dart';
import 'chiptune_sync_delegate.dart';

class ChiptuneTool {
  ChiptuneTool._();
  static ToolModel get config => ToolModel(
    id: 'chiptune',
    name: 'Chiptune Player',
    description: 'Play tracker modules and audio files',
    icon: Icons.music_note_outlined,
    route: '/chiptune',
    accentColor: AppTheme.accentPurple,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameChiptune,
    descriptionL10n: (l10n) => l10n.toolDescChiptune,
    shareTarget: ShareTargetConfig(
      accept: [
        'audio/x-mod',
        'audio/x-xm',
        'audio/x-it',
        'audio/x-s3m',
        'audio/wav',
        'audio/mpeg',
        'audio/ogg',
        'audio/flac',
        'audio/mp4',
        'audio/aac',
        'audio/opus',
        'audio/x-ms-wma',
        'audio/aiff',
        'audio/amr',
        'audio/x-matroska',
        'application/octet-stream',
      ],
    ),
    fileExtensions: [
      'mod',
      'xm',
      'it',
      's3m',
      'wav',
      'mp3',
      'ogg',
      'flac',
      'aac',
      'aiff',
      'aif',
      'alac',
      'amr',
      'm4a',
      'mka',
      'opus',
      'wma',
    ],
    createPage: (sd) => ChiptunePage(sharedFile: sd?.firstFile),
    syncDelegateFactory: ChiptuneSyncDelegate.new,
    stateProviders: () => [
      ChangeNotifierProvider<ChiptuneState>(create: (_) => ChiptuneState()),
      ChangeNotifierProvider<ChiptunePlaybackState>(
        create: (_) => ChiptunePlaybackState(),
      ),
    ],
  );
}
