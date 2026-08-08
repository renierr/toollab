import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/collapsible_section.dart';

import '../health_record.dart';
import 'health_record_details_page.dart';

class HealthMetricHistory extends StatelessWidget {
  final List<HealthRecord> records;
  final String valueKey;
  final String unit;

  const HealthMetricHistory({
    super.key,
    required this.records,
    required this.valueKey,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(AppLocalizations.of(context).healthDashboardNoData),
        ),
      );
    }
    return Column(
      children: _groups(context)
          .map(
            (group) => CollapsibleSection(
              icon: Icons.calendar_month_outlined,
              title: group.title,
              initiallyExpanded: group.isRecent,
              child: Column(
                children: group.records
                    .map(
                      (record) => _HealthRecordTile(
                        record: record,
                        valueKey: valueKey,
                        unit: unit,
                      ),
                    )
                    .toList(),
              ),
            ),
          )
          .toList(),
    );
  }

  List<_HealthRecordGroup> _groups(BuildContext context) {
    final cutoff = DateTime.now().subtract(const Duration(days: 6));
    final recent = <HealthRecord>[];
    final monthly = <String, List<HealthRecord>>{};
    for (final record in records) {
      final date = DateTime.fromMillisecondsSinceEpoch(record.startTime);
      if (!date.isBefore(cutoff)) {
        recent.add(record);
      } else {
        final title = DateFormat.yMMMM(
          Localizations.localeOf(context).toString(),
        ).format(date);
        monthly.putIfAbsent(title, () => []).add(record);
      }
    }
    return [
      if (recent.isNotEmpty)
        _HealthRecordGroup(
          AppLocalizations.of(context).treadmillHistoryLastSevenDays,
          recent,
          true,
        ),
      ...monthly.entries.map(
        (entry) => _HealthRecordGroup(entry.key, entry.value, false),
      ),
    ];
  }
}

class _HealthRecordGroup {
  final String title;
  final List<HealthRecord> records;
  final bool isRecent;

  const _HealthRecordGroup(this.title, this.records, this.isRecent);
}

class _HealthRecordTile extends StatelessWidget {
  final HealthRecord record;
  final String valueKey;
  final String unit;

  const _HealthRecordTile({
    required this.record,
    required this.valueKey,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(record.startTime);
    final value = record.type == 'sleep.session'
        ? Duration(
            milliseconds: record.endTime - record.startTime,
          ).inMinutes.toDouble()
        : (record.value[valueKey] as num?)?.toDouble();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.history_rounded),
        title: Text(MaterialLocalizations.of(context).formatMediumDate(date)),
        subtitle: Text(
          record.sourceName ??
              AppLocalizations.of(context).healthDashboardHealthConnect,
        ),
        trailing: Text(value == null ? '-' : _format(value)),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HealthRecordDetailsPage(record: record),
          ),
        ),
      ),
    );
  }

  String _format(double value) => switch (unit) {
    'kg' => '${value.toStringAsFixed(1)} kg',
    'bpm' => '${value.round()} bpm',
    'steps' => value.round().toString(),
    'min' => '${value.round()} min',
    'calories' => value.round().toString(),
    _ => value.toStringAsFixed(1),
  };
}
