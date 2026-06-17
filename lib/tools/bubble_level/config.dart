import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'bubble_level_page.dart';

class BubbleLevelTool {
  BubbleLevelTool._();

  static ToolModel get config => ToolModel(
    id: 'bubble-level',
    name: 'Bubble Level',
    description: 'Precision spirit level using sensors',
    icon: Icons.sensors_outlined,
    route: '/bubble-level',
    accentColor: AppTheme.accentGreen,
    sectionId: 'sensors',
    nameL10n: (l10n) => l10n.toolNameBubbleLevel,
    descriptionL10n: (l10n) => l10n.toolDescBubbleLevel,
    createPage: (_) => const BubbleLevelPage(),
  );
}
