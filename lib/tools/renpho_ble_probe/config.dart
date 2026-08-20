import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'renpho_ble_probe_page.dart';
import 'renpho_ble_probe_state.dart';
import 'renpho_sync_delegate.dart';

class RenphoBleProbeTool {
  RenphoBleProbeTool._();

  static ToolModel get config => ToolModel(
    id: 'renpho-ble-probe',
    name: 'Renpho Local Scale',
    description:
        'Local MorphoScan Nova body-composition scans, stored on this device.',
    icon: Icons.monitor_weight_outlined,
    route: '/renpho-ble-probe',
    accentColor: AppTheme.accentPurple,
    sectionId: 'sensors',
    nameL10n: (l10n) => l10n.toolNameRenphoScale,
    descriptionL10n: (l10n) => l10n.toolDescRenphoScale,
    createPage: (_) => const RenphoBleProbePage(),
    syncDelegateFactory: RenphoSyncDelegate.new,
    stateProviders: () => [
      ChangeNotifierProvider<RenphoBleProbeState>(
        create: (_) => RenphoBleProbeState(),
      ),
    ],
  );
}
