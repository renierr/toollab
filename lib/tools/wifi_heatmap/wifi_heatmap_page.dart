import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/core/tool_page_state.dart';

import 'config.dart';
import 'wifi_heatmap_state.dart';
import 'widgets/wifi_heatmap_grid.dart';

class WifiHeatmapPage extends StatefulWidget {
  const WifiHeatmapPage({super.key});

  @override
  State<WifiHeatmapPage> createState() => _WifiHeatmapPageState();
}

class _WifiHeatmapPageState extends State<WifiHeatmapPage>
    with DisposeCleanup {
  @override
  void initState() {
    super.initState();
    onDispose(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WifiHeatmapState>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ToolLayout(
      title: WifiHeatmapTool.config.localizedName(l10n),
      fullscreen: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.wifi_find_outlined),
          tooltip: 'Scan',
          onPressed: state.scanning ? null : () => state.scan(),
        ),
        IconButton(
          icon: Icon(
            state.showHeatmap ? Icons.grid_on_outlined : Icons.grid_off_outlined,
          ),
          tooltip: 'Toggle heatmap',
          onPressed: () => state.toggleHeatmap(!state.showHeatmap),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Clear samples',
          onPressed: state.samples.isEmpty ? null : state.clearSamples,
        ),
      ],
      child: Column(
        children: [
          if (!state.isSupported)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'WiFi scanning is only supported on Android.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                state.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.accentRed,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: state.selectedSsid,
                    hint: const Text('Select network'),
                    items: _buildNetworkItems(state.scanned),
                    onChanged: (v) {
                      if (v != null) state.selectNetwork(v);
                    },
                  ),
                ),
                if (state.scanning)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: WifiHeatmapGrid(
                cols: state.cols,
                rows: state.rows,
                samples: state.samples,
                showHeatmap: state.showHeatmap,
                onTap: (x, y) => state.recordSample(x, y),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                _legendDot(AppTheme.accentRed, 'Poor'),
                const SizedBox(width: 8),
                _legendDot(AppTheme.accentAmber, 'Fair'),
                const SizedBox(width: 8),
                _legendDot(AppTheme.accentGreen, 'Good'),
                const Spacer(),
                Text('Tap a cell to sample'),
                const SizedBox(width: 12),
                Text('Samples: ${state.samples.length}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildNetworkItems(
    List<dynamic> scanned,
  ) {
    final seen = <String>{};
    final list = <DropdownMenuItem<String>>[];
    for (final a in scanned) {
      final ssid = a.ssid as String;
      final bssid = a.bssid as String;
      final level = a.level as int;
      final key = ssid.isNotEmpty ? ssid : bssid;
      if (seen.add(key)) {
        list.add(
          DropdownMenuItem<String>(
            value: key,
            child: Text('$key ($level dBm)'),
          ),
        );
      }
    }
    return list;
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
