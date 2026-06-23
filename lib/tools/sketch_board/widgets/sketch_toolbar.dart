import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_chip.dart';

import '../models/sketch_enums.dart';
import '../sketch_board_state.dart';

class SketchToolbar extends StatelessWidget {
  const SketchToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.read<SketchBoardState>();
    final theme = Theme.of(context);

    final tools = <(ToolMode, IconData, String)>[
      (ToolMode.select, Icons.near_me_outlined, l10n.sketchToolSelect),
      (ToolMode.pan, Icons.pan_tool_outlined, l10n.sketchToolPan),
      (ToolMode.freehand, Icons.gesture, l10n.sketchToolPen),
      (ToolMode.line, Icons.horizontal_rule, l10n.sketchToolLine),
      (ToolMode.arrow, Icons.arrow_right_alt, l10n.sketchToolArrow),
      (ToolMode.rect, Icons.crop_square, l10n.sketchToolRect),
      (ToolMode.ellipse, Icons.circle_outlined, l10n.sketchToolEllipse),
      (ToolMode.diamond, Icons.diamond_outlined, l10n.sketchToolDiamond),
      (ToolMode.text, Icons.text_fields, l10n.sketchToolText),
    ];

    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.95),
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Selector<SketchBoardState, ToolMode>(
          selector: (_, s) => s.mode,
          builder: (context, selected, _) => Wrap(
            spacing: 2,
            runSpacing: 2,
            alignment: WrapAlignment.center,
            children: [
              for (final t in tools)
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
            ],
          ),
        ),
      ),
    );
  }
}
