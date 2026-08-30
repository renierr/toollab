import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'chaindrop_page.dart';
import 'chaindrop_state.dart';

/// Chain Drop's registry entry.
///
/// The id is a single lowercase word so it doubles cleanly as the route path
/// and, on Android, the PascalCase token the launcher-shortcut tooling derives
/// an activity-alias class name from.
class ChainDropTool {
  ChainDropTool._();

  static ToolModel get config => ToolModel(
    id: 'chaindrop',
    name: 'Chain Drop',
    description:
        'Drop numbered discs into a 7x7 well, clear runs that match their '
        'value, and chase the chain reactions before the rising cracked '
        'discs bury you.',
    icon: Icons.blur_circular,
    route: '/chaindrop',
    accentColor: AppTheme.accentGreen,
    sectionId: 'games',
    nameL10n: (l10n) => l10n.toolNameChainDrop,
    descriptionL10n: (l10n) => l10n.toolDescChainDrop,
    createPage: (_) => const ChainDropPage(),
    stateProviders: () => [
      ChangeNotifierProvider<ChainDropState>(create: (_) => ChainDropState()),
    ],
    androidProcessIsolated: true,
  );
}
