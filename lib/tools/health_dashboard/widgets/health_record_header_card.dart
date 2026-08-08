import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import 'health_source_badge.dart';

class HealthRecordHeaderCard extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final String? sourceName;

  const HealthRecordHeaderCard({
    super.key,
    required this.start,
    required this.end,
    this.sourceName,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateStr = MaterialLocalizations.of(context).formatFullDate(start);
    final startTimeStr = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(start));
    final endTimeStr = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(end));
    final duration = end.difference(start);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateStr,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time_outlined, size: 18),
                const SizedBox(width: 8),
                Text(
                  duration.inMinutes > 0
                      ? '$startTimeStr - $endTimeStr (${duration.inMinutes} min)'
                      : startTimeStr,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            if (sourceName != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '${l10n.healthDashboardSource}: ',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  HealthSourceBadge(packageName: sourceName),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
