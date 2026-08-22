import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'workout_details_stats.dart';

class WorkoutHrZoneBar extends StatelessWidget {
  final List<HeartRateZone> zones;
  final int totalSeconds;
  final List<String> zoneNames;

  const WorkoutHrZoneBar({
    super.key,
    required this.zones,
    required this.totalSeconds,
    required this.zoneNames,
  });

  static const List<Color> _colors = [
    AppTheme.statusBlue,
    AppTheme.statusGreen,
    AppTheme.statusAmber,
    AppTheme.statusOrange,
    AppTheme.statusRed,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = totalSeconds <= 0 ? 1 : totalSeconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                for (int i = 0; i < zones.length; i++)
                  if (zones[i].seconds > 0)
                    Expanded(
                      flex: zones[i].seconds,
                      child: ColoredBox(color: _colors[i]),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < zones.length; i++)
          if (zones[i].seconds > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _colors[i],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Z${zones[i].index} · ${zoneNames[i]}',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${zones[i].lowerBpm}–${zones[i].upperBpm} bpm',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 62,
                    child: Text(
                      formatWorkoutClock(zones[i].seconds),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${(zones[i].seconds / total * 100).round()}%',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
