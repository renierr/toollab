import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_database.dart';
import '../health_record.dart';
import 'health_record_details_page.dart';
import 'health_source_badge.dart';

class HealthAllDataPage extends StatefulWidget {
  const HealthAllDataPage({super.key});

  @override
  State<HealthAllDataPage> createState() => _HealthAllDataPageState();
}

class _HealthAllDataPageState extends State<HealthAllDataPage> {
  final _records = <HealthRecord>[];
  var _isLoading = true;
  var _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading && _records.isNotEmpty || !_hasMore) return;
    final page = await HealthDatabase.instance.recordsPage(
      typePrefix: 'health.',
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthDashboardAllData)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
          ? Center(child: Text(l10n.healthDashboardNoData))
          : NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.extentAfter < 240) _loadMore();
                return false;
              },
              child: ListView.builder(
                itemCount: _records.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) => index == _records.length
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _HealthDataTile(record: _records[index]),
              ),
            ),
    );
  }
}

class _HealthDataTile extends StatelessWidget {
  final HealthRecord record;

  const _HealthDataTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(record.startTime);
    final details = _details();
    return ListTile(
      leading: const Icon(Icons.health_and_safety_outlined),
      title: Text(record.value['dataType'] as String? ?? record.type),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(MaterialLocalizations.of(context).formatMediumDate(date)),
          if (details != null) Text(details),
          HealthSourceBadge(packageName: record.sourceName),
        ],
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HealthRecordDetailsPage(record: record),
        ),
      ),
    );
  }

  String? _details() {
    if (record.value['floors'] case final num floors) {
      return '${floors.round()} floors';
    }
    if (record.value['minutes'] case final num minutes) {
      return '${minutes.round()} min';
    }
    if (record.value['systolicMmhg'] case final num systolic) {
      final diastolic = (record.value['diastolicMmhg'] as num?)?.round();
      return diastolic == null
          ? '${systolic.round()} mmHg'
          : '${systolic.round()}/$diastolic mmHg';
    }
    if (record.value['percent'] case final num percent) {
      return '${percent.toStringAsFixed(1)} %';
    }
    if (record.value['bmi'] case final num bmi) {
      return 'BMI ${bmi.toStringAsFixed(1)}';
    }
    if (record.value['centimeters'] case final num centimeters) {
      return '${centimeters.toStringAsFixed(1)} cm';
    }
    if (record.value['liters'] case final num liters) {
      return '${liters.toStringAsFixed(2)} L';
    }
    return null;
  }
}
