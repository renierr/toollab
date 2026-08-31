import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'luma_well_page.dart';
import 'luma_well_state.dart';

class LumaWellTool {
  LumaWellTool._();

  static ToolModel get config => ToolModel(
    id: 'luma-well',
    name: 'Luma Well',
    description:
        'Place glowing orbs around a turning well and combine equals into brighter forms.',
    icon: Icons.bubble_chart_outlined,
    route: '/luma-well',
    accentColor: AppTheme.accentTeal,
    sectionId: 'games',
    nameL10n: (l10n) => l10n.toolNameLumaWell,
    descriptionL10n: (l10n) => l10n.toolDescLumaWell,
    createPage: (_) => const LumaWellPage(),
    stateProviders: () => [
      ChangeNotifierProvider<LumaWellState>(create: (_) => LumaWellState()),
    ],
    androidProcessIsolated: true,
  );
}
