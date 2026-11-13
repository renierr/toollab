import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../ink_recognizer.dart';
import '../models/sketch_element.dart';
import '../sketch_board_state.dart';

typedef _SelInfo = ({bool has, int count, bool group, bool rotated, bool ink});

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
        rotated: s.hasRotatedSelection,
        ink: s.selectedInk.isNotEmpty,
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
                if (info.ink && SketchInkRecognizer.isSupported)
                  const _InkRecognitionButtons(),
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
                if (info.rotated)
                  IconButton(
                    tooltip: l10n.sketchResetRotation,
                    icon: const Icon(Icons.restart_alt, size: 20),
                    onPressed: state.resetRotation,
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

class _InkRecognitionButtons extends StatelessWidget {
  const _InkRecognitionButtons();

  Future<void> _run(
    BuildContext context,
    Future<bool> Function(SketchBoardState state, List<FreehandElement> ink)
    action,
  ) async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<SketchBoardState>();
    final messenger = ScaffoldMessenger.of(context);
    final ink = state.selectedInk;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.sketchInkRecognizing),
        duration: const Duration(minutes: 1),
      ),
    );
    try {
      final done = await action(state, ink);
      messenger.hideCurrentSnackBar();
      if (!done) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.sketchInkNothingRecognized)),
        );
      }
    } catch (e) {
      errorLog('[SketchBoard] Ink recognition failed: $e');
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.sketchInkFailed(e.toString()))),
      );
    }
  }

  static bool _unchanged(SketchBoardState state, List<FreehandElement> ink) =>
      listEquals(state.selectedInk, ink);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.sketchInkToText,
          icon: const Icon(Icons.text_fields, size: 20),
          visualDensity: VisualDensity.compact,
          onPressed: () => _run(context, (state, ink) async {
            final text = await SketchInkRecognizer.recognizeText(ink, language);
            if (text == null || text.trim().isEmpty) return false;
            if (_unchanged(state, ink)) state.replaceInkWithText(text);
            return true;
          }),
        ),
        IconButton(
          tooltip: l10n.sketchInkToShape,
          icon: const Icon(Icons.auto_fix_high, size: 20),
          visualDensity: VisualDensity.compact,
          onPressed: () => _run(context, (state, ink) async {
            final shape = await SketchInkRecognizer.recognizeShape(ink);
            if (shape == null) return false;
            if (_unchanged(state, ink)) state.replaceInkWithShape(shape);
            return true;
          }),
        ),
      ],
    );
  }
}
