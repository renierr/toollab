import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_dashboard_state.dart';
import '../health_record.dart';
import 'health_record_details_page.dart';
import 'health_source_badge.dart';

class HealthAllDataPage extends StatelessWidget {
  const HealthAllDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final records = context
        .watch<HealthDashboardState>()
        .records
        .where((record) => record.type.startsWith('health.'))
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthDashboardAllData)),
      body: records.isEmpty
          ? Center(child: Text(l10n.healthDashboardNoData))
          : ListView.builder(
              itemCount: records.length,
              itemBuilder: (context, index) =>
                  _HealthDataTile(record: records[index]),
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
    return ListTile(
      leading: const Icon(Icons.health_and_safety_outlined),
      title: Text(record.value['dataType'] as String? ?? record.type),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(MaterialLocalizations.of(context).formatMediumDate(date)),
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
}
