import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'twenty48_page.dart';
import 'twenty48_state.dart';

/// 2048's registry entry.
///
/// The id is spelled out (`twenty48`, not `2048`) because it doubles as the
/// route path and, on Android, the PascalCase token the launcher-shortcut
/// tooling derives an activity-alias class name from — neither may start with
/// a digit. The displayed name stays the real "2048".
class Twenty48Tool {
  Twenty48Tool._();

  static ToolModel get config => ToolModel(
    id: 'twenty48',
    name: '2048',
    description:
        'Swipe to slide the board, merge equal tiles, and chase a single '
        '2048 out of a grid that keeps filling up.',
    icon: Icons.grid_4x4,
    route: '/twenty48',
    accentColor: AppTheme.accentAmber,
    sectionId: 'games',
    nameL10n: (l10n) => l10n.toolName2048,
    descriptionL10n: (l10n) => l10n.toolDesc2048,
    createPage: (_) => const Twenty48Page(),
    stateProviders: () => [
      ChangeNotifierProvider<Twenty48State>(create: (_) => Twenty48State()),
    ],
    androidProcessIsolated: true,
  );
}
