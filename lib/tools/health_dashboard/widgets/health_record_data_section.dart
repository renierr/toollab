import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_record.dart';
import '../health_source_apps.dart';
import '../store/health_metric_catalog.dart';
import '../store/health_queries.dart';

/// Everything stored about one record: which app wrote it, what it is called
/// internally next to our own naming, its identity in Health Connect, and the
/// raw values last.
class HealthRecordDataSection extends StatelessWidget {
  final HealthRecord record;

  const HealthRecordDataSection({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final metric = HealthQueries.metricForType(record.type);
    final spec = metric == null ? null : HealthMetrics.spec(metric);
    final duration = Duration(milliseconds: record.endTime - record.startTime);

    final rows = <(String, String, bool)>[
      (
        l10n.healthDashboardMetaApp,
        healthAppLabel(record.sourceName, l10n),
        false,
      ),
      if (record.sourceName != null)
        (l10n.healthDashboardMetaPackage, record.sourceName!, true),
      (l10n.healthDashboardMetaOurType, record.type, true),
      if (metric != null) (l10n.healthDashboardMetaMetricKey, metric, true),
      if (record.value['dataType'] case final String dataType)
        (l10n.healthDashboardMetaRecordType, dataType, true),
      if (record.value['exerciseType'] case final String activity)
        (l10n.healthDashboardMetaActivity, activity, true),
      if (spec != null) ...[
        if (spec.unit.isNotEmpty)
          (l10n.healthDashboardMetaUnit, spec.unit, true),
        (l10n.healthDashboardMetaAggregation, spec.aggregation.name, true),
        (l10n.healthDashboardMetaShape, spec.shape.name, true),
      ],
      (l10n.healthDashboardMetaSource, record.source.name, true),
      (l10n.healthDashboardMetaRowId, record.id, true),
      if (record.sourceRecordId.isNotEmpty)
        (l10n.healthDashboardMetaOrigin, record.sourceRecordId, true),
      if (record.value['clientRecordId'] case final String clientId)
        (l10n.healthDashboardMetaClientId, clientId, true),
      if (record.deviceId case final String deviceId)
        (l10n.healthDashboardMetaDevice, deviceId, true),
      if (record.duplicateOf case final String duplicateOf)
        (l10n.healthDashboardMetaDuplicateOf, duplicateOf, true),
      (l10n.healthDashboardMetaStart, _stamp(context, record.startTime), false),
      (l10n.healthDashboardMetaEnd, _stamp(context, record.endTime), false),
      if (duration > Duration.zero)
        (
          l10n.healthDashboardMetaDuration,
          '${duration.inMinutes} min (${record.endTime - record.startTime} ms)',
          false,
        ),
      (
        l10n.healthDashboardMetaAggregateIncluded,
        _yesNo(l10n, record.aggregateIncluded),
        false,
      ),
      (l10n.healthDashboardMetaSynced, _yesNo(l10n, record.synced), false),
      if (record.deleted)
        (l10n.healthDashboardMetaDeleted, _yesNo(l10n, true), false),
    ];

    return Card(
      child: ExpansionTile(
        title: Text(l10n.healthDashboardData),
        subtitle: Text(
          metric == null ? record.type : '${record.type} · $metric',
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            color: theme.hintColor,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, value, mono) in rows)
                  _MetaRow(label: label, value: value, mono: mono),
                const SizedBox(height: 12),
                Text(
                  l10n.healthDashboardMetaRawValues,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(record.value),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _yesNo(AppLocalizations l10n, bool value) =>
      value ? l10n.commonYes : l10n.commonNo;

  static String _stamp(BuildContext context, int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final materialL10n = MaterialLocalizations.of(context);
    final time = materialL10n.formatTimeOfDay(
      TimeOfDay.fromDateTime(date),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return '${materialL10n.formatMediumDate(date)} $time';
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _MetaRow({
    required this.label,
    required this.value,
    required this.mono,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          SelectableText(
            value,
            style: mono
                ? theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
