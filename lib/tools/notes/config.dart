import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

class NotesTool {
  NotesTool._();

  static const ToolModel config = ToolModel(
    id: 'notes',
    name: 'Notes',
    description:
        'Simple note taking tool with Markdown support and backend sync',
    icon: Icons.note_alt_outlined,
    route: '/notes',
    accentColor: AppTheme.accentTeal,
    sectionId: 'utilities',
    fullscreen: true,
    shareTarget: ShareTargetConfig(accept: ['text/markdown', 'text/plain']),
  );
}
