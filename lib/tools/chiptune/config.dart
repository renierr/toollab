import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

class ChiptuneTool {
  ChiptuneTool._();
  static const ToolModel config = ToolModel(
    id: 'chiptune',
    name: 'Chiptune Player',
    description: 'Play Amiga MOD, XM and IT tracker modules',
    icon: Icons.music_note_outlined,
    route: '/chiptune',
    accentColor: AppTheme.accentPurple,
    sectionId: 'utilities',
    shareTarget: ShareTargetConfig(accept: ['application/octet-stream']),
  );
}
