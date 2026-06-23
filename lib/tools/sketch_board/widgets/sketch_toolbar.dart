import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_chip.dart';

import '../models/sketch_enums.dart';
import '../sketch_board_state.dart';

const _shapeModes = {
  ToolMode.line,
  ToolMode.arrow,
  ToolMode.doubleArrow,
  ToolMode.rect,
  ToolMode.ellipse,
  ToolMode.triangle,
  ToolMode.diamond,
  ToolMode.hexagon,
  ToolMode.speechBubble,
  ToolMode.checkmark,
};

class SketchToolbar extends StatelessWidget {
  const SketchToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.read<SketchBoardState>();
    final theme = Theme.of(context);

    final primary = <(ToolMode, IconData, String)>[
      (ToolMode.pan, Icons.pan_tool_outlined, l10n.sketchToolPan),
      (ToolMode.select, Icons.near_me_outlined, l10n.sketchToolSelect),
      (ToolMode.freehand, Icons.gesture, l10n.sketchToolPen),
    ];
    final shapes = <(ToolMode, IconData, String)>[
      (ToolMode.line, Icons.horizontal_rule, l10n.sketchToolLine),
      (ToolMode.arrow, Icons.arrow_right_alt, l10n.sketchToolArrow),
      (ToolMode.doubleArrow, Icons.sync_alt, l10n.sketchToolDoubleArrow),
      (ToolMode.rect, Icons.crop_square, l10n.sketchToolRect),
      (ToolMode.ellipse, Icons.circle_outlined, l10n.sketchToolEllipse),
      (ToolMode.triangle, Icons.change_history, l10n.sketchToolTriangle),
      (ToolMode.diamond, Icons.diamond_outlined, l10n.sketchToolDiamond),
      (ToolMode.hexagon, Icons.hexagon_outlined, l10n.sketchToolHexagon),
      (
        ToolMode.speechBubble,
        Icons.chat_bubble_outline,
        l10n.sketchToolSpeechBubble,
      ),
      (ToolMode.checkmark, Icons.check, l10n.sketchToolCheckmark),
    ];

    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.95),
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Selector<SketchBoardState, ToolMode>(
          selector: (_, s) => s.mode,
          builder: (context, selected, _) {
            final activeShape = shapes
                .where((s) => s.$1 == selected)
                .firstOrNull;
            return Wrap(
              spacing: 2,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final t in primary)
                  Tooltip(
                    message: t.$3,
                    child: ToolChip(
                      icon: t.$2,
                      label: t.$3,
                      showLabel: false,
                      selected: selected == t.$1,
                      onTap: () => state.setMode(t.$1),
                    ),
                  ),
                _ShapesMenu(
                  shapes: shapes,
                  active: activeShape,
                  selectedMode: selected,
                  onSelected: state.setMode,
                ),
                Tooltip(
                  message: l10n.sketchToolText,
                  child: ToolChip(
                    icon: Icons.text_fields,
                    label: l10n.sketchToolText,
                    showLabel: false,
                    selected: selected == ToolMode.text,
                    onTap: () => state.setMode(ToolMode.text),
                  ),
                ),
                if (selected == ToolMode.select) const _SelectionTypeToggle(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SelectionTypeToggle extends StatelessWidget {
  const _SelectionTypeToggle();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.read<SketchBoardState>();
    return Selector<SketchBoardState, SelectionType>(
      selector: (_, s) => s.selectionType,
      builder: (context, type, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: l10n.sketchSelectBox,
            child: ToolChip(
              icon: Icons.highlight_alt,
              label: l10n.sketchSelectBox,
              showLabel: false,
              selected: type == SelectionType.box,
              onTap: () => state.setSelectionType(SelectionType.box),
            ),
          ),
          Tooltip(
            message: l10n.sketchSelectLasso,
            child: ToolChip(
              icon: Icons.polyline,
              label: l10n.sketchSelectLasso,
              showLabel: false,
              selected: type == SelectionType.lasso,
              onTap: () => state.setSelectionType(SelectionType.lasso),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShapesMenu extends StatelessWidget {
  final List<(ToolMode, IconData, String)> shapes;
  final (ToolMode, IconData, String)? active;
  final ToolMode selectedMode;
  final ValueChanged<ToolMode> onSelected;

  const _ShapesMenu({
    required this.shapes,
    required this.active,
    required this.selectedMode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isActive = _shapeModes.contains(selectedMode);

    return PopupMenuButton<ToolMode>(
      tooltip: l10n.sketchToolShapes,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final s in shapes)
          PopupMenuItem(
            value: s.$1,
            child: Row(
              children: [
                Icon(s.$2, size: 18),
                const SizedBox(width: 10),
                Text(s.$3),
                if (selectedMode == s.$1) ...[
                  const Spacer(),
                  Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
                ],
              ],
            ),
          ),
      ],
      child: Material(
        color: isActive
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active?.$2 ?? Icons.category_outlined,
                size: 16,
                color: isActive
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: isActive
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
