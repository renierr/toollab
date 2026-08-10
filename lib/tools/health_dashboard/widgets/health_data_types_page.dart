import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_dashboard_state.dart';
import 'health_busy_dialog.dart';
import 'health_data_sources_page.dart';

/// Per-type pull selection. Only enabled types are read from Health Connect, so
/// this list is the first and cheapest duplicate defence: a type nobody selects
/// costs nothing to import.
class HealthDataTypesPage extends StatefulWidget {
  const HealthDataTypesPage({super.key});

  @override
  State<HealthDataTypesPage> createState() => _HealthDataTypesPageState();
}

class _HealthDataTypesPageState extends State<HealthDataTypesPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      if (!mounted) return;
      await context.read<HealthDashboardState>().loadSelection();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<HealthDashboardState>();
    final types = state.healthTypes;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthDashboardDataTypes)),
      body: types.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.healthDashboardNoTypesFound,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView.builder(
              itemCount: types.length,
              itemBuilder: (context, index) {
                final type = types[index];
                final sources = state.discoveredApps[type.type] ?? const [];
                return SwitchListTile.adaptive(
                  title: Text(_label(type.type)),
                  subtitle: Text(
                    [
                      if (type.count > 0)
                        l10n.healthDashboardTypeRecordCount(type.count),
                      if (sources.isNotEmpty) '${sources.length} apps',
                    ].join(' - '),
                  ),
                  secondary: sources.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.account_tree_outlined),
                          tooltip: l10n.healthDashboardDataSources,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  HealthDataSourcesPage(type: type.type),
                            ),
                          ),
                        ),
                  value: type.enabled,
                  onChanged: state.isCollecting
                      ? null
                      : (value) => state.setTypeEnabled(type.type, value),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => state.isCollecting
            ? HealthBusyDialog.show(context)
            : state.runDiscovery(),
        icon: const Icon(Icons.travel_explore_rounded),
        label: Text(l10n.healthDashboardScanSources),
      ),
    );
  }

  /// Health Connect type ids are snake_case; this is only cosmetic.
  static String _label(String typeId) => typeId
      .split('_')
      .map(
        (word) =>
            word.isEmpty ? word : word[0].toUpperCase() + word.substring(1),
      )
      .join(' ');
}
