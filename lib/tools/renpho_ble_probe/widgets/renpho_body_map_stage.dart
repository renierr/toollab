import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../renpho_body_geometry.dart';
import '../renpho_body_metrics.dart';
import '../renpho_segment_labels.dart';
import 'renpho_body_figure.dart';
import 'renpho_segment_chip.dart';

/// The figure with its callouts. Pointing at a body part or its callout
/// reports the segment; tapping selects it.
class RenphoBodyMapStage extends StatelessWidget {
  final List<RenphoSegmentValues> segments;
  final RenphoSegment active;
  final ValueChanged<RenphoSegment> onSelect;
  final ValueChanged<RenphoSegment?> onHover;

  const RenphoBodyMapStage({
    super.key,
    required this.segments,
    required this.active,
    required this.onSelect,
    required this.onHover,
  });

  RenphoSegment? _segmentAt(Offset position, Size size) {
    final figure = RenphoBodyGeometry.figureRect(size);
    for (final values in segments) {
      if (RenphoBodyGeometry.path(values.segment, figure).contains(position)) {
        return values.segment;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth,
          (constraints.maxWidth * 0.95).clamp(320.0, 420.0),
        );
        final callouts = [
          for (final values in segments)
            (
              values: values,
              rect: RenphoBodyGeometry.calloutRect(
                values.segment,
                size,
                RenphoBodyGeometry.calloutHeight,
              ),
            ),
        ];
        return SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            children: [
              Positioned.fill(
                child: MouseRegion(
                  onHover: (event) =>
                      onHover(_segmentAt(event.localPosition, size)),
                  onExit: (_) => onHover(null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (details) {
                      final segment = _segmentAt(details.localPosition, size);
                      if (segment != null) onSelect(segment);
                    },
                    child: RenphoBodyFigure(segments: segments, active: active),
                  ),
                ),
              ),
              // Height is left to the chip so a large text scale grows it
              // downwards instead of overflowing.
              for (final callout in callouts)
                Positioned(
                  left: callout.rect.left,
                  top: callout.rect.top,
                  width: callout.rect.width,
                  child: RenphoSegmentChip(
                    label: callout.values.segment.label(l10n),
                    muscle:
                        '${callout.values.muscleMassKg.toStringAsFixed(2)} kg',
                    fat: '${callout.values.fatMassKg.toStringAsFixed(2)} kg',
                    color: RenphoBodyGeometry.tint(
                      callout.values.muscleOfStandardPercent,
                    ),
                    active: callout.values.segment == active,
                    onTap: () => onSelect(callout.values.segment),
                    onHover: (hovering) =>
                        onHover(hovering ? callout.values.segment : null),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
