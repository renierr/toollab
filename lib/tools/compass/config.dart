import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'compass_page.dart';
import 'compass_state.dart';

class CompassTool {
  CompassTool._();

  static ToolModel get config => ToolModel(
    id: 'compass',
    name: 'Compass',
    description: 'Tilt-compensated heading dial with magnetic status',
    icon: Icons.explore_outlined,
    route: '/compass',
    accentColor: AppTheme.accentRed,
    sectionId: 'sensors',
    nameL10n: (l10n) => l10n.toolNameCompass,
    descriptionL10n: (l10n) => l10n.toolDescCompass,
    createPage: (_) => const CompassPage(),
    stateProviders: () => [
      ChangeNotifierProvider<CompassState>(create: (_) => CompassState()),
    ],
  );
}
