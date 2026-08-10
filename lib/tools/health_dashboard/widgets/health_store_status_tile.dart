import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../store/health_schema.dart';
import '../store/health_store.dart';

/// What the store actually holds, so an empty dashboard is distinguishable from
/// a broken one without opening a database.
class HealthStoreStatusTile extends StatelessWidget {
  const HealthStoreStatusTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return FutureBuilder<Map<String, int>>(
      future: HealthStore.instance.rowCounts(),
      builder: (context, snapshot) {
        final counts = snapshot.data;
        final measurements =
            (counts?[HealthSchema.point] ?? 0) +
            (counts?[HealthSchema.interval] ?? 0);
        final sessions = counts?[HealthSchema.session] ?? 0;
        final isEmpty = counts != null && measurements == 0 && sessions == 0;
        return ListTile(
          leading: Icon(
            isEmpty ? Icons.inbox_outlined : Icons.storage_rounded,
            color: isEmpty ? theme.hintColor : null,
          ),
          title: Text(
            counts == null
                ? l10n.commonLoading
                : l10n.healthDashboardStoreSummary(measurements, sessions),
          ),
          subtitle: Text(
            isEmpty
                ? l10n.healthDashboardStoreEmptyHint
                : l10n.healthDashboardStoreRollupRows(
                    counts?[HealthSchema.daily] ?? 0,
                  ),
          ),
        );
      },
    );
  }
}
