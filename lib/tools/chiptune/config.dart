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
    description: 'Play Amiga MOD, XM and IT tracker modules',
    icon: Icons.music_note_outlined,
    route: '/chiptune',
    accentColor: AppTheme.accentPurple,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameChiptune,
    descriptionL10n: (l10n) => l10n.toolDescChiptune,
    shareTarget: ShareTargetConfig(accept: ['application/octet-stream']),
    fileExtensions: ['mod', 'xm', 'it', 's3m'],
    createPage: (sd) => ChiptunePage(sharedFile: sd?.firstFile),
    syncDelegateFactory: ChiptuneSyncDelegate.new,
  );
}
