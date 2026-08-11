import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_dashboard_state.dart';
import '../health_record.dart';
import '../health_value_format.dart';
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

  bool get _isSleep => record.type == 'sleep.session';

  bool get _spansTime => record.endTime - record.startTime >= 60000;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final materialL10n = MaterialLocalizations.of(context);
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    // A sleep session belongs to the morning it ends on; everything else is
    // stamped where it started.
    final date = DateTime.fromMillisecondsSinceEpoch(
      _isSleep ? record.endTime : record.startTime,
    );
    final value = _isSleep
        ? Duration(
            milliseconds: record.endTime - record.startTime,
          ).inMinutes.toDouble()
        : (record.value[valueKey] as num?)?.toDouble();

    String time(int millis) => materialL10n.formatTimeOfDay(
      TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(millis)),
      alwaysUse24HourFormat: use24h,
    );

    final when = _spansTime
        ? '${time(record.startTime)} - ${time(record.endTime)}'
        : time(record.startTime);

    return Card(
      child: ListTile(
        leading: Icon(
          isNap ? Icons.nightlight_outlined : Icons.history_rounded,
        ),
        title: Text(
          '${materialL10n.formatMediumDate(date)} · $when'
          '${isNap ? ' · ${l10n.healthDashboardNap}' : ''}',
        ),
        subtitle: HealthSourceBadge(packageName: record.sourceName),
        trailing: Text(
          value == null ? '-' : _format(value),
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
    'min' => _isSleep ? _sleepDuration(value.round()) : '${value.round()} min',
    _ => healthValue(value, unit),
  };

  String _sleepDuration(int minutes) =>
      '${minutes ~/ 60}h ${minutes.remainder(60)}m';
}
