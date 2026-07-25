import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/tool_chip.dart';

enum FastDropMode { cloud, nearby }

/// Segmented toggle between the cloud-relay ("Cloud") and BLE/LAN
/// peer-to-peer ("Nearby") modes of the Fast Drop tool.
class FastDropModeToggle extends StatelessWidget {
  final FastDropMode mode;
  final String cloudLabel;
  final String nearbyLabel;
  final ValueChanged<FastDropMode> onChanged;

  const FastDropModeToggle({
    super.key,
    required this.mode,
    required this.cloudLabel,
    required this.nearbyLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ToolChip(
          icon: Icons.cloud_outlined,
          label: cloudLabel,
          selected: mode == FastDropMode.cloud,
          onTap: () => onChanged(FastDropMode.cloud),
        ),
        ToolChip(
          icon: Icons.bluetooth_searching,
          label: nearbyLabel,
          selected: mode == FastDropMode.nearby,
          onTap: () => onChanged(FastDropMode.nearby),
        ),
      ],
    );
  }
}
