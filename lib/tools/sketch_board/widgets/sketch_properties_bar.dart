import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/sketch_element.dart';
import '../models/sketch_enums.dart';
import '../sketch_board_colors.dart';
import '../sketch_board_state.dart';
import 'sketch_color_picker.dart';

typedef _Props = ({
  String stroke,
  String? fill,
  double width,
  bool fillCtx,
  bool textCtx,
  bool brushCtx,
  bool imageCtx,
  BrushStyle brush,
  bool bold,
  bool italic,
});

const _nonDrawModes = {
  ToolMode.select,
  ToolMode.pan,
  ToolMode.text,
  ToolMode.image,
};

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
        final isFillShape =
            sel is ShapeElement && _fillableTypes.contains(sel.shapeType);
        final fillCtx = _fillModes.contains(s.mode) || isFillShape;
        final textCtx = s.mode == ToolMode.text || sel is TextElement;
        final strokeShape = sel is FreehandElement || sel is ShapeElement;
        final brushCtx =
            strokeShape || (sel == null && !_nonDrawModes.contains(s.mode));
        final brush = strokeShape
            ? brushStyleFromWire(sel!.brushStyle)
            : s.brushStyle;
        final imageCtx = sel is ImageElement;
        // Reflect the selected element when one is active; otherwise the tool
        // defaults used for the next drawn element.
        return (
          stroke: sel?.color ?? s.strokeColor,
          fill: isFillShape ? sel.fillColor : s.fillColor,
          width: sel?.width ?? s.strokeWidth,
          fillCtx: fillCtx,
          textCtx: textCtx,
          brushCtx: brushCtx,
          imageCtx: imageCtx,
          brush: brush,
          bold: sel is TextElement ? sel.fontWeight == 'bold' : s.fontBold,
          italic: sel is TextElement ? sel.fontStyle == 'italic' : s.fontItalic,
        );
      },
      builder: (context, p, _) {
        return Material(
          color: theme.colorScheme.surface.withValues(alpha: 0.95),
          elevation: 3,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ColorButton(
                  label: l10n.sketchPropStroke,
                  hex: p.stroke,
                  onPicked: state.setStrokeColor,
                ),
                if (p.fillCtx)
                  _ColorButton(
                    label: l10n.sketchPropFill,
                    hex: p.fill,
                    allowNone: true,
                    onPicked: state.setFillColor,
                  ),
                _WidthControl(width: p.width, onChanged: state.setStrokeWidth),
                if (p.brushCtx)
                  _BrushControl(brush: p.brush, onChanged: state.setBrushStyle),
                if (p.textCtx)
                  Row(
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
                if (p.imageCtx)
                  IconButton(
                    tooltip: l10n.sketchResetImageSize,
                    icon: const Icon(Icons.aspect_ratio_outlined, size: 18),
                    onPressed: state.resetImageSize,
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

class _ColorButton extends StatelessWidget {
  final String label;
  final String? hex;
  final bool allowNone;
  final void Function(String) onPicked;

  const _ColorButton({
    required this.label,
    required this.hex,
    required this.onPicked,
    this.allowNone = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = colorFromHexOrNull(hex);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await showSketchColorPicker(
          context,
          current: hex,
          allowNone: allowNone,
        );
        if (picked != null) onPicked(picked);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color ?? Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: color == null
                  ? Icon(
                      Icons.block,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _BrushControl extends StatelessWidget {
  final BrushStyle brush;
  final ValueChanged<BrushStyle> onChanged;

  const _BrushControl({required this.brush, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final items = <(BrushStyle, IconData, String)>[
      (BrushStyle.normal, Icons.remove, l10n.sketchBrushNormal),
      (BrushStyle.shaky, Icons.gesture, l10n.sketchBrushShaky),
      (BrushStyle.natural, Icons.brush, l10n.sketchBrushNatural),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.sketchPropBrush,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        for (final it in items)
          Tooltip(
            message: it.$3,
            child: GestureDetector(
              onTap: () => onChanged(it.$1),
              child: Container(
                width: 28,
                height: 26,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: brush == it.$1
                      ? theme.colorScheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  it.$2,
                  size: 16,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WidthControl extends StatelessWidget {
  final double width;
  final ValueChanged<double> onChanged;

  const _WidthControl({required this.width, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppLocalizations.of(context).sketchPropWidth,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        for (final w in SketchBoardColors.strokeWidths)
          GestureDetector(
            onTap: () => onChanged(w),
            child: Container(
              width: 26,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: width == w
                    ? theme.colorScheme.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Container(
                  width: 4 + w * 1.4,
                  height: 4 + w * 1.4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
