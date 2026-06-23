import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/sketch_element.dart';
import '../models/sketch_enums.dart';
import '../sketch_board_colors.dart';
import '../sketch_board_state.dart';

typedef _Props = ({
  String stroke,
  String? fill,
  double width,
  bool fillCtx,
  bool textCtx,
  bool bold,
  bool italic,
});

const _fillableTypes = {
  'rect',
  'ellipse',
  'triangle',
  'diamond',
  'hexagon',
  'speech-bubble',
};

const _fillModes = {
  ToolMode.rect,
  ToolMode.ellipse,
  ToolMode.triangle,
  ToolMode.diamond,
  ToolMode.hexagon,
  ToolMode.speechBubble,
};

class SketchPropertiesBar extends StatelessWidget {
  const SketchPropertiesBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.read<SketchBoardState>();
    final theme = Theme.of(context);

    return Selector<SketchBoardState, _Props>(
      selector: (_, s) {
        final sel = s.selectedElement;
        final fillCtx =
            _fillModes.contains(s.mode) ||
            (sel is ShapeElement && _fillableTypes.contains(sel.shapeType));
        final textCtx = s.mode == ToolMode.text || sel is TextElement;
        return (
          stroke: s.strokeColor,
          fill: s.fillColor,
          width: s.strokeWidth,
          fillCtx: fillCtx,
          textCtx: textCtx,
          bold: s.fontBold,
          italic: s.fontItalic,
        );
      },
      builder: (context, p, _) {
        return Material(
          color: theme.colorScheme.surface.withValues(alpha: 0.95),
          elevation: 3,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Group(
                  label: l10n.sketchPropStroke,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final hex in SketchBoardColors.strokeSwatches)
                        _Swatch(
                          hex: hex,
                          selected: p.stroke == hex,
                          onTap: () => state.setStrokeColor(hex),
                        ),
                    ],
                  ),
                ),
                if (p.fillCtx)
                  _Group(
                    label: l10n.sketchPropFill,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final hex in SketchBoardColors.fillSwatches)
                          _Swatch(
                            hex: hex,
                            selected: (p.fill ?? 'transparent') == hex,
                            onTap: () => state.setFillColor(hex),
                          ),
                      ],
                    ),
                  ),
                _Group(
                  label: l10n.sketchPropWidth,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final w in SketchBoardColors.strokeWidths)
                        _WidthDot(
                          width: w,
                          selected: p.width == w,
                          color: theme.colorScheme.onSurface,
                          onTap: () => state.setStrokeWidth(w),
                        ),
                    ],
                  ),
                ),
                if (p.textCtx)
                  _Group(
                    label: l10n.sketchPropText,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          isSelected: p.bold,
                          onPressed: state.toggleBold,
                          icon: const Icon(Icons.format_bold, size: 18),
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          isSelected: p.italic,
                          onPressed: state.toggleItalic,
                          icon: const Icon(Icons.format_italic, size: 18),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Group extends StatelessWidget {
  final String label;
  final Widget child;
  const _Group({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 6),
        child,
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final String hex;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = colorFromHexOrNull(hex);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color ?? Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: color == null
            ? Icon(
                Icons.block,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              )
            : null,
      ),
    );
  }
}

class _WidthDot extends StatelessWidget {
  final double width;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _WidthDot({
    required this.width,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dot = 4.0 + width * 1.4;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
