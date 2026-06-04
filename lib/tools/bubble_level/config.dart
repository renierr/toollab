import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

class BubbleLevelTool {
  BubbleLevelTool._();

  static const ToolModel config = ToolModel(
    id: 'bubble-level',
    name: 'Bubble Level',
    description: 'Precision spirit level using sensors',
    icon: Icons.sensors_outlined,
    route: '/bubble-level',
    accentColor: AppTheme.accentGreen,
    sectionId: 'sensors',
    fullscreen: true,
  );
}
