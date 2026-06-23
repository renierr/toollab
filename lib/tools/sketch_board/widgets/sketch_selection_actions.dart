import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../sketch_board_state.dart';

typedef _SelInfo = ({bool has, int count, bool group});

class SketchSelectionActions extends StatelessWidget {
  const SketchSelectionActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Selector<SketchBoardState, _SelInfo>(
      selector: (_, s) => (
        has: s.hasSelection,
        count: s.selectionCount,
        group: s.hasGroupSelected,
      ),
      builder: (context, info, _) {
        if (!info.has) return const SizedBox.shrink();
        final state = context.read<SketchBoardState>();
        return Material(
          color: theme.colorScheme.surface.withValues(alpha: 0.95),
          elevation: 3,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: l10n.sketchBringToFront,
                  icon: const Icon(Icons.flip_to_front, size: 20),
                  onPressed: state.bringToFront,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: l10n.sketchSendToBack,
                  icon: const Icon(Icons.flip_to_back, size: 20),
                  onPressed: state.sendToBack,
                  visualDensity: VisualDensity.compact,
                ),
                if (info.count >= 2)
                  IconButton(
                    tooltip: l10n.sketchGroup,
                    icon: const Icon(
                      Icons.dashboard_customize_outlined,
                      size: 20,
                    ),
                    onPressed: state.groupSelected,
                    visualDensity: VisualDensity.compact,
                  ),
                if (info.group)
                  IconButton(
                    tooltip: l10n.sketchUngroup,
                    icon: const Icon(Icons.grid_view_outlined, size: 20),
                    onPressed: state.ungroupSelected,
                    visualDensity: VisualDensity.compact,
                  ),
                IconButton(
                  tooltip: l10n.commonDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppTheme.statusRed,
                  ),
                  onPressed: state.deleteSelected,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
