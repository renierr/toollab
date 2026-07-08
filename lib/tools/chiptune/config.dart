import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'chiptune_page.dart';
import 'chiptune_sync_delegate.dart';

class ChiptuneTool {
  ChiptuneTool._();
  static ToolModel get config => ToolModel(
    id: 'chiptune',
    name: 'Chiptune Player',
    description: 'Play MOD, XM, IT tracker modules and WAV, MP3, OGG audio',
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
        'application/octet-stream',
      ],
    ),
    fileExtensions: ['mod', 'xm', 'it', 's3m', 'wav', 'mp3', 'ogg', 'flac'],
    createPage: (sd) => ChiptunePage(sharedFile: sd?.firstFile),
    syncDelegateFactory: ChiptuneSyncDelegate.new,
  );
}
