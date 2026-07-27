import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';
import 'treadmill_control_page.dart';
import 'treadmill_control_state.dart';
import 'treadmill_sync_delegate.dart';

class TreadmillControlTool {
  TreadmillControlTool._();

  static ToolModel get config => ToolModel(
    id: 'treadmill-control',
    name: 'Treadmill Control',
    description: 'Control your treadmill and monitor heart rate via Bluetooth',
    icon: Icons.directions_run_outlined,
    route: '/treadmill-control',
    accentColor: AppTheme.accentTeal,
    sectionId: 'sensors',
    nameL10n: (l10n) => l10n.toolNameTreadmillControl,
    descriptionL10n: (l10n) => l10n.toolDescTreadmillControl,
    createPage: (_) => const TreadmillControlPage(),
    syncDelegateFactory: TreadmillSyncDelegate.new,
    stateProviders: () => [
      ChangeNotifierProvider<TreadmillControlState>(
        create: (_) => TreadmillControlState(),
      ),
    ],
  );
}
