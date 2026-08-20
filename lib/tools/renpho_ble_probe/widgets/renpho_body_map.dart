import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../renpho_body_metrics.dart';
import 'renpho_body_map_stage.dart';
import 'renpho_segment_detail.dart';

/// The segment breakdown as a body: every part carries its own callout, and
/// touching or hovering one opens its full set of values beside it.
class RenphoBodyMap extends StatefulWidget {
  final RenphoDerived derived;

  const RenphoBodyMap({super.key, required this.derived});

  @override
  State<RenphoBodyMap> createState() => _RenphoBodyMapState();
}

class _RenphoBodyMapState extends State<RenphoBodyMap> {
  RenphoSegment? _selected;
  RenphoSegment? _hovered;

  Map<RenphoSegment, RenphoSegmentValues> get _values => {
    for (final values in widget.derived.segments) values.segment: values,
  };

  RenphoSegment? _activeIn(Map<RenphoSegment, RenphoSegmentValues> values) {
    final active = _hovered ?? _selected;
    if (active != null && values.containsKey(active)) return active;
    return values.containsKey(RenphoSegment.trunk)
        ? RenphoSegment.trunk
        : values.keys.firstOrNull;
  }

  void _hover(RenphoSegment? segment) {
    if (_hovered != segment) setState(() => _hovered = segment);
  }

  @override
  Widget build(BuildContext context) {
    final values = _values;
    final active = _activeIn(values);
    if (active == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final stage = RenphoBodyMapStage(
      segments: widget.derived.segments,
      active: active,
      onSelect: (segment) => setState(() => _selected = segment),
      onHover: _hover,
    );
    final detail = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RenphoSegmentDetail(values: values[active]!),
        const SizedBox(height: 8),
        Text(
          l10n.renphoSegmentMapHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 620
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: stage),
                const SizedBox(width: 16),
                Expanded(flex: 6, child: detail),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [stage, const SizedBox(height: 12), detail],
            ),
    );
  }
}
