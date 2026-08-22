import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/widgets/workout/workout_session.dart';
import '../../../l10n/app_localizations.dart';

class SessionHistoryListItem extends StatelessWidget {
  final TreadmillSession session;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const SessionHistoryListItem({
    super.key,
    required this.session,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = DateTime.fromMillisecondsSinceEpoch(session.startTime);
    final minutes = session.elapsedTime ~/ 60;
    final seconds = session.elapsedTime % 60;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(
          DateFormat.yMMMd(
            Localizations.localeOf(context).toString(),
          ).add_Hm().format(date),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${session.distance.toStringAsFixed(2)} km | ${minutes}m ${seconds}s | ${l10n.treadmillHistoryAverageHr}: ${session.avgHeartRate.round()} bpm',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: l10n.commonDelete,
          onPressed: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }
}
