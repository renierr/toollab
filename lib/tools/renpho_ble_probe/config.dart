import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'renpho_ble_probe_page.dart';
import 'renpho_ble_probe_state.dart';

class RenphoBleProbeTool {
  RenphoBleProbeTool._();

  static ToolModel get config => ToolModel(
    id: 'renpho-ble-probe',
    name: 'Renpho Local Scale',
    description:
        'Local MorphoScan Nova body-composition scans without cloud sync.',
    icon: Icons.monitor_heart_outlined,
    route: '/renpho-ble-probe',
    accentColor: AppTheme.accentBlue,
    sectionId: 'sensors',
    createPage: (_) => const RenphoBleProbePage(),
    stateProviders: () => [
      ChangeNotifierProvider<RenphoBleProbeState>(
        create: (_) => RenphoBleProbeState(),
      ),
    ],
  );
}
