import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import 'health_session_timeline.dart';

/// The session timeline plus its legend, where the overlay entries are switches.
///
/// Only the curves toggle. A sleep stage cannot: the bar is a continuous
/// timeline, and hiding one would leave a hole rather than a filtered view. With
/// no stages - a workout - the stage swatches are left out entirely.
class HealthSessionTimelineSection extends StatefulWidget {
  final int startTime;
  final int endTime;
  final List<Map<String, dynamic>> stages;

  /// Everything that could be laid over this session. An overlay with no samples
  /// during it stays in the legend, greyed out - otherwise a curve that exists
  /// everywhere else looks like it was never implemented.
  final List<HealthSessionOverlay> overlays;

  /// Curves switched on when the section first builds.
  final Set<String> initiallyEnabled;

  const HealthSessionTimelineSection({
    super.key,
    required this.startTime,
    required this.endTime,
    this.stages = const [],
    this.overlays = const [],
    this.initiallyEnabled = const {'heart_rate'},
  });

  @override
  State<HealthSessionTimelineSection> createState() =>
      _HealthSessionTimelineSectionState();
}

class _HealthSessionTimelineSectionState
    extends State<HealthSessionTimelineSection> {
  Set<String>? _enabled;

  /// Heart rate on by default - it is the one curve a session is usually read
  /// against. The rest stay off so the chart opens uncluttered.
  Set<String> get _selection => _enabled ??= {
    for (final overlay in widget.overlays)
      if (overlay.isDrawable && widget.initiallyEnabled.contains(overlay.key))
        overlay.key,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selection = _selection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (widget.stages.isNotEmpty) ...[
              _LegendEntry(
                color: Colors.amber,
                label: l10n.healthDashboardSleepAwake,
              ),
              _LegendEntry(
                color: Colors.purple,
                label: l10n.healthDashboardSleepRem,
              ),
              _LegendEntry(
                color: Colors.lightBlue,
                label: l10n.healthDashboardSleepLight,
              ),
              _LegendEntry(
                color: Colors.indigo,
                label: l10n.healthDashboardSleepDeep,
              ),
            ],
            for (final overlay in widget.overlays)
              _LegendEntry(
                color: overlay.color,
                label: overlay.label,
                selected: selection.contains(overlay.key),
                unavailable: !overlay.isDrawable,
                onTap: overlay.isDrawable
                    ? () => setState(() {
                        if (!selection.remove(overlay.key)) {
                          selection.add(overlay.key);
                        }
                      })
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: HealthSessionTimeline(
              stages: widget.stages,
              startTime: widget.startTime,
              endTime: widget.endTime,
              overlays: [
                for (final overlay in widget.overlays)
                  if (overlay.isDrawable && selection.contains(overlay.key))
                    overlay,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One legend entry. Stage colours are plain swatches; a toggleable overlay is
/// the same swatch filled when on and outlined when off, so the two read as one
/// legend rather than a legend with buttons stuck to it.
class _LegendEntry extends StatelessWidget {
  final Color color;
  final String label;
  final bool selected;
  final bool unavailable;
  final VoidCallback? onTap;

  const _LegendEntry({
    required this.color,
    required this.label,
    this.selected = true,
    this.unavailable = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = unavailable || !selected;
    final swatch = unavailable ? theme.hintColor : color;
    final entry = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: dim ? Colors.transparent : swatch,
            border: Border.all(color: swatch, width: 1.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: dim ? theme.hintColor : null,
            decoration: unavailable ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
    if (onTap == null) return entry;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: entry,
      ),
    );
  }
}
