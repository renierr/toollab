import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_dashboard_state.dart';
import '../health_record.dart';
import 'health_record_details_page.dart';
import 'health_source_badge.dart';

class HealthRecordTile extends StatelessWidget {
  final HealthRecord record;
  final String valueKey;
  final String unit;
  final bool isNap;

  const HealthRecordTile({
    super.key,
    required this.record,
    required this.valueKey,
    required this.unit,
    required this.isNap,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      record.type == 'sleep.session' ? record.endTime : record.startTime,
    );
    final value = record.type == 'sleep.session'
        ? Duration(
            milliseconds: record.endTime - record.startTime,
          ).inMinutes.toDouble()
        : (record.value[valueKey] as num?)?.toDouble();
    return Card(
      child: ListTile(
        leading: Icon(
          isNap ? Icons.nightlight_outlined : Icons.history_rounded,
        ),
        title: Text(
          isNap
              ? '${MaterialLocalizations.of(context).formatMediumDate(date)} · ${AppLocalizations.of(context).healthDashboardNap}'
              : MaterialLocalizations.of(context).formatMediumDate(date),
        ),
        subtitle: HealthSourceBadge(packageName: record.sourceName),
        trailing: Text(value == null ? '-' : _format(value)),
        onTap: () {
          final selected = DateTime(date.year, date.month, date.day);
          context.read<HealthDashboardState>().selectDay(selected);
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => HealthRecordDetailsPage(record: record),
            ),
          );
        },
      ),
    );
  }

  String _format(double value) => switch (unit) {
    'kg' => '${value.toStringAsFixed(1)} kg',
    'bpm' => '${value.round()} bpm',
    'steps' => value.round().toString(),
    'min' =>
      record.type == 'sleep.session'
          ? _sleepDuration(value.round())
          : '${value.round()} min',
    'calories' => value.round().toString(),
    _ => value.toStringAsFixed(1),
  };

  String _sleepDuration(int minutes) =>
      '${minutes ~/ 60}h ${minutes.remainder(60)}m';
}
