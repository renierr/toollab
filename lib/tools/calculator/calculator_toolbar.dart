import 'package:flutter/material.dart';

class CalculatorToolbar extends StatelessWidget {
  final bool showScientific;
  final VoidCallback onToggleSci;
  final VoidCallback onShowHistory;
  final VoidCallback onCopy;
  final VoidCallback onBackspace;

  const CalculatorToolbar({
    super.key,
    required this.showScientific,
    required this.onToggleSci,
    required this.onShowHistory,
    required this.onCopy,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _ToolbarChip(
            icon: Icons.science_outlined,
            label: 'SCI',
            selected: showScientific,
            onTap: onToggleSci,
          ),
          const SizedBox(width: 4),
          _ToolbarChip(
            icon: Icons.history,
            label: 'HIST',
            onTap: onShowHistory,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            onPressed: onCopy,
            tooltip: 'Copy result',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.backspace_outlined, size: 20),
            onPressed: onBackspace,
            tooltip: 'Backspace',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ToolbarChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToolbarChip({
    required this.icon,
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface.withAlpha(180),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface.withAlpha(180),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
