import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import 'health_sleep_stage_timeline.dart';

/// The stage timeline plus its legend, where the overlay entries are switches.
///
/// Only the curves toggle. A sleep stage cannot: the bar is a continuous
/// timeline, and hiding one would leave a hole rather than a filtered view.
class HealthSleepTimelineSection extends StatefulWidget {
  final List<Map<String, dynamic>> stages;
  final int startTime;
  final int endTime;

  /// Everything available for this session; the ones with too few samples are
  /// shown as unavailable rather than silently dropped.
  final List<HealthSleepOverlay> overlays;

  const HealthSleepTimelineSection({
    super.key,
    required this.stages,
    required this.startTime,
    required this.endTime,
    this.overlays = const [],
  });

  @override
  State<HealthSleepTimelineSection> createState() =>
      _HealthSleepTimelineSectionState();
}

class _HealthSleepTimelineSectionState
    extends State<HealthSleepTimelineSection> {
  /// Heart rate on by default - it is the one curve a night is usually read
  /// against. The rest stay off so the chart opens uncluttered.
  static const _onByDefault = {'heart_rate'};

  Set<String>? _enabled;

  Set<String> get _selection => _enabled ??= {
    for (final overlay in widget.overlays)
      if (overlay.isDrawable && _onByDefault.contains(overlay.key)) overlay.key,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final drawable = widget.overlays.where((o) => o.isDrawable).toList();
    final selection = _selection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _StageSwatch(
              color: Colors.amber,
              label: l10n.healthDashboardSleepAwake,
            ),
            _StageSwatch(
              color: Colors.purple,
              label: l10n.healthDashboardSleepRem,
            ),
            _StageSwatch(
              color: Colors.lightBlue,
              label: l10n.healthDashboardSleepLight,
            ),
            _StageSwatch(
              color: Colors.indigo,
              label: l10n.healthDashboardSleepDeep,
            ),
            for (final overlay in drawable)
              FilterChip(
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                avatar: CircleAvatar(backgroundColor: overlay.color, radius: 5),
                label: Text(overlay.label),
                selected: selection.contains(overlay.key),
                onSelected: (on) => setState(() {
                  if (on) {
                    selection.add(overlay.key);
                  } else {
                    selection.remove(overlay.key);
                  }
                }),
              ),
            if (drawable.isEmpty) Text(l10n.healthDashboardNoSleepHeartRate),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: HealthSleepStageTimeline(
              stages: widget.stages,
              startTime: widget.startTime,
              endTime: widget.endTime,
              overlays: [
                for (final overlay in drawable)
                  if (selection.contains(overlay.key)) overlay,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StageSwatch extends StatelessWidget {
  final Color color;
  final String label;

  const _StageSwatch({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
