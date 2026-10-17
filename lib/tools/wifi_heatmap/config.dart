import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'wifi_heatmap_page.dart';
import 'wifi_heatmap_state.dart';

class WifiHeatmapTool {
  WifiHeatmapTool._();

  static ToolModel get config => ToolModel(
        id: 'wifi-heatmap',
        name: 'WiFi Signal Heatmap',
        description: 'Map Wi-Fi signal strength across a space',
        icon: Icons.wifi_tethering_outlined,
        route: '/wifi-heatmap',
        accentColor: AppTheme.accentBlue,
        sectionId: 'sensors',
        nameL10n: (l10n) => l10n.toolNameWifiHeatmap,
        descriptionL10n: (l10n) => l10n.toolDescWifiHeatmap,
        createPage: (shared) => const WifiHeatmapPage(),
        stateProviders: () => [
          ChangeNotifierProvider<WifiHeatmapState>(
            create: (_) => WifiHeatmapState(),
          ),
        ],
      );
}
