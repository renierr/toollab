import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'drift_bloom_page.dart';
import 'drift_bloom_state.dart';

class DriftBloomTool {
  DriftBloomTool._();

  static ToolModel get config => ToolModel(
    id: 'drift-bloom',
    name: 'Drift Bloom',
    description: 'Steer a drifting seed through wind rings and bloom petals.',
    icon: Icons.air_outlined,
    route: '/drift-bloom',
    accentColor: AppTheme.accentGreen,
    sectionId: 'games',
    nameL10n: (l10n) => l10n.toolNameDriftBloom,
    descriptionL10n: (l10n) => l10n.toolDescDriftBloom,
    createPage: (_) => const DriftBloomPage(),
    stateProviders: () => [
      ChangeNotifierProvider<DriftBloomState>(create: (_) => DriftBloomState()),
    ],
    androidProcessIsolated: true,
  );
}
