import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';

import '../config.dart';
import '../health_dashboard_state.dart';
import '../health_source_apps.dart';
import '../store/health_store.dart';
import 'health_busy_dialog.dart';
import 'health_delete_app_dialog.dart';

/// Every app that has written data, across all types.
///
/// Two independent controls per writer, which are easy to confuse:
///
/// - **The switch** decides whether the writer counts at all. Off means it is
///   not pulled and not aggregated, while its stored rows stay put.
/// - **The order** decides who wins when two writers describe the same day. The
///   topmost writer with data for a metric on a day is the one that day's total
///   is computed from, so a republisher can stay on as a fallback without
///   inflating anything.
class HealthAppsPage extends StatefulWidget {
  const HealthAppsPage({super.key});

  @override
  State<HealthAppsPage> createState() => _HealthAppsPageState();
}

class _HealthAppsPageState extends State<HealthAppsPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      if (!mounted) return;
      final state = context.read<HealthDashboardState>();
      await state.loadSelection();
      if (!mounted) return;
      await state.loadAppRowCounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<HealthDashboardState>();
    final apps = state.healthApps;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthDashboardApps)),
      body: apps.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.healthDashboardNoAppsFound,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView(
              children: [
                SettingsSectionLabel(
                  title: l10n.healthDashboardAppPriority,
                  description: l10n.healthDashboardAppPriorityHint,
                ),
                for (var index = 0; index < apps.length; index++)
                  _HealthAppTile(
                    app: apps[index],
                    rowCount: state.appRowCounts[apps[index].appId],
                    isFirst: index == 0,
                    isLast: index == apps.length - 1,
                    onMove: (delta) => _move(index, delta),
                  ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Future<void> _move(int index, int delta) async {
    final state = context.read<HealthDashboardState>();
    if (state.isCollecting) {
      HealthBusyDialog.show(context);
      return;
    }
    final order = state.healthApps.map((app) => app.package).toList();
    final target = index + delta;
    if (target < 0 || target >= order.length) return;
    final moved = order.removeAt(index);
    order.insert(target, moved);
    await state.setAppOrder(order);
  }
}

class _HealthAppTile extends StatelessWidget {
  final HealthAppState app;
  final int? rowCount;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<int> onMove;

  const _HealthAppTile({
    required this.app,
    required this.rowCount,
    required this.isFirst,
    required this.isLast,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<HealthDashboardState>();
    final label = healthAppLabel(app.package, l10n);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(healthAppIcon(app.package), color: theme.hintColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: theme.textTheme.titleSmall),
                        // The package is the only unambiguous identifier when two
                        // installed apps carry the same brand name.
                        if (label != app.package)
                          Text(
                            app.package,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: app.enabled,
                    onChanged: state.isCollecting
                        ? null
                        : (value) => context
                              .read<HealthDashboardState>()
                              .setAppEnabled(app.package, value),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    rowCount == null
                        ? l10n.commonLoading
                        : l10n.healthDashboardAppRowCount(rowCount!),
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    l10n.healthDashboardAppTypeCount(app.typeCount),
                    style: theme.textTheme.bodySmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_upward_rounded),
                    tooltip: l10n.healthDashboardAppMoveUp,
                    onPressed: isFirst ? null : () => onMove(-1),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward_rounded),
                    tooltip: l10n.healthDashboardAppMoveDown,
                    onPressed: isLast ? null : () => onMove(1),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: l10n.healthDashboardAppDeleteData,
                    color: AppTheme.accentRed,
                    onPressed: state.isCollecting
                        ? null
                        : () => _confirmDelete(context, label),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String label) async {
    final state = context.read<HealthDashboardState>();
    final scope = await HealthDeleteAppDialog.show(
      context,
      label: label,
      canChooseScope: context.read<AppState>().syncsTool(
        HealthDashboardTool.config.id,
      ),
    );
    if (scope == null) return;
    await state.deleteAppData(
      app.package,
      everywhere: scope == HealthDeleteScope.everywhere,
    );
  }
}
