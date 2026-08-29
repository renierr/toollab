import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'ricochet_page.dart';
import 'ricochet_state.dart';

class RicochetTool {
  RicochetTool._();

  static ToolModel get config => ToolModel(
    id: 'ricochet',
    name: 'Ricochet',
    description: 'Aim bouncing balls and destroy numbered bricks.',
    icon: Icons.sports_baseball_outlined,
    route: '/ricochet',
    accentColor: AppTheme.accentBlue,
    sectionId: 'games',
    nameL10n: (l10n) => l10n.toolNameRicochet,
    descriptionL10n: (l10n) => l10n.toolDescRicochet,
    createPage: (_) => const RicochetPage(),
    stateProviders: () => [
      ChangeNotifierProvider<RicochetState>(create: (_) => RicochetState()),
    ],
    androidProcessIsolated: true,
  );
}
