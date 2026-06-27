import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'bluetooth_scanner_page.dart';
import 'bluetooth_scanner_state.dart';

class BluetoothScannerTool {
  BluetoothScannerTool._();

  static ToolModel get config => ToolModel(
    id: 'bluetooth-scanner',
    name: 'Bluetooth Scanner',
    description:
        'Scan for nearby Bluetooth Low Energy devices and identify them.',
    icon: Icons.bluetooth_searching,
    route: '/bluetooth-scanner',
    accentColor: AppTheme.accentBlue,
    sectionId: 'sensors',
    nameL10n: (l10n) => l10n.toolNameBluetoothScanner,
    descriptionL10n: (l10n) => l10n.toolDescBluetoothScanner,
    createPage: (_) => const BluetoothScannerPage(),
    stateProviders: () => [
      ChangeNotifierProvider<BluetoothScannerState>(
        create: (_) => BluetoothScannerState(),
      ),
    ],
  );
}
