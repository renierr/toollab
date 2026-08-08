import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_record.dart';

class HealthRecordDetailsPage extends StatelessWidget {
  final HealthRecord record;

  const HealthRecordDetailsPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final start = DateTime.fromMillisecondsSinceEpoch(record.startTime);
    final end = DateTime.fromMillisecondsSinceEpoch(record.endTime);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthDashboardDetails)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _RecordField(
            label: l10n.healthDashboardDate,
            value: MaterialLocalizations.of(context).formatFullDate(start),
          ),
          _RecordField(
            label: l10n.healthDashboardTime,
            value:
                '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(start))} - ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(end))}',
          ),
          if (record.sourceName != null)
            _RecordField(
              label: l10n.healthDashboardSource,
              value: record.sourceName!,
            ),
          _RecordField(
            label: l10n.healthDashboardData,
            value: const JsonEncoder.withIndent('  ').convert(record.value),
            selectable: true,
          ),
        ],
      ),
    );
  }
}

class _RecordField extends StatelessWidget {
  final String label;
  final String value;
  final bool selectable;

  const _RecordField({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label),
    subtitle: selectable ? SelectableText(value) : Text(value),
  );
}
