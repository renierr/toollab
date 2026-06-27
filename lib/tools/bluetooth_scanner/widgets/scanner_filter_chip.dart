import 'package:flutter/material.dart';
import 'package:tool_lab/tools/bluetooth_scanner/bluetooth_scanner_state.dart';

class ScannerFilterChip extends StatelessWidget {
  final DeviceFilter filter;
  final String label;
  final IconData icon;
  final bool isActive;
  final ValueChanged<DeviceFilter> onToggle;

  const ScannerFilterChip({
    super.key,
    required this.filter,
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      selected: isActive,
      label: Text(label, style: theme.textTheme.labelSmall),
      avatar: Icon(icon, size: 14),
      onSelected: (_) => onToggle(filter),
      visualDensity: VisualDensity.compact,
    );
  }
}
