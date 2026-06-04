import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/tool_chip.dart';

class CalculatorToolbar extends StatelessWidget {
  final bool showScientific;
  final VoidCallback onToggleSci;
  final VoidCallback onShowHistory;
  final VoidCallback onCopy;
  final VoidCallback onBackspace;
  final bool isShort;

  const CalculatorToolbar({
    super.key,
    required this.showScientific,
    required this.onToggleSci,
    required this.onShowHistory,
    required this.onCopy,
    required this.onBackspace,
    this.isShort = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: isShort ? 0 : 4),
      child: Row(
        children: [
          ToolChip(
            icon: Icons.science_outlined,
            label: 'SCI',
            selected: showScientific,
            onTap: onToggleSci,
            showLabel: !isShort,
          ),
          const SizedBox(width: 4),
          ToolChip(
            icon: Icons.history,
            label: 'HIST',
            onTap: onShowHistory,
            showLabel: !isShort,
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.copy, size: isShort ? 18 : 20),
            onPressed: onCopy,
            tooltip: 'Copy result',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(Icons.backspace_outlined, size: isShort ? 18 : 20),
            onPressed: onBackspace,
            tooltip: 'Backspace',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
