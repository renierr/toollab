import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/collapsible_section.dart';

import '../store/health_queries.dart';
import '../health_record.dart';
import 'health_empty_state.dart';
import 'health_record_tile.dart';

class HealthMetricHistory extends StatefulWidget {
  final String type;
  final String valueKey;
  final String unit;
  final bool Function(HealthRecord record) isNap;

  const HealthMetricHistory({
    super.key,
    required this.type,
    required this.valueKey,
    required this.unit,
    required this.isNap,
  });

  @override
  State<HealthMetricHistory> createState() => _HealthMetricHistoryState();
}

class _HealthMetricHistoryState extends State<HealthMetricHistory> {
  final _records = <HealthRecord>[];
  var _isLoading = true;
  var _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if ((_isLoading && _records.isNotEmpty) || !_hasMore) return;
    final page = await HealthQueries.instance.recordsPage(
      type: widget.type,
      offset: _records.length,
    );
    if (!mounted) return;
    setState(() {
      _records.addAll(page);
      _hasMore = page.length == 100;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: HealthEmptyState(),
      );
    }
    return Column(
      children: [
        for (final group in _groups(context))
          CollapsibleSection(
            icon: Icons.calendar_month_outlined,
            title: group.title,
            initiallyExpanded: group.isRecent,
            child: Column(
              children: [
                for (final record in group.records)
                  HealthRecordTile(
                    record: record,
                    valueKey: widget.valueKey,
                    unit: widget.unit,
                    isNap: widget.isNap(record),
                  ),
              ],
            ),
          ),
        if (_hasMore)
          TextButton(onPressed: _loadMore, child: const Text('Load more')),
      ],
    );
  }

  List<_HealthRecordGroup> _groups(BuildContext context) {
    final cutoff = DateTime.now().subtract(const Duration(days: 6));
    final recent = <HealthRecord>[];
    final monthly = <String, List<HealthRecord>>{};
    final naps = <HealthRecord>[];
    final nightlyRecords = <HealthRecord>[];
    for (final record in _records) {
      if (record.type == 'sleep.session' && widget.isNap(record)) {
        naps.add(record);
      } else {
        nightlyRecords.add(record);
      }
    }
    for (final record in nightlyRecords) {
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
      if (naps.isNotEmpty)
        _HealthRecordGroup(
          AppLocalizations.of(context).healthDashboardNaps,
          naps,
          false,
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
