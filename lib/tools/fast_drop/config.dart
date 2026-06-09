import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

class FastDropTool {
  FastDropTool._();

  static const ToolModel config = ToolModel(
    id: 'fast-drop',
    name: 'Fast Drop',
    description:
        'Quickly drop files or paste clipboard data to the server for temporary storage and sharing',
    icon: Icons.cloud_upload_outlined,
    route: '/fast-drop',
    accentColor: AppTheme.accentTeal,
    sectionId: 'utilities',
    shareTarget: ShareTargetConfig(accept: ['*/*']),
  );
}
