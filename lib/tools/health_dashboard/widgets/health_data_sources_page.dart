import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../health_dashboard_state.dart';

/// Which writing apps a type is pulled from.
///
/// This is where the Google Fit duplication is actually solved. Google Fit
/// republishes other apps' data, so a device with both a direct writer and
/// Google Fit sees each measurement twice. Deselecting one means its rows are
/// never read - the filter is applied by Health Connect itself.
class HealthDataSourcesPage extends StatelessWidget {
  final String type;

  const HealthDataSourcesPage({required this.type, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<HealthDashboardState>();
    final sources = state.discoveredApps[type] ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthDashboardDataSources)),
      body: sources.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.healthDashboardNoSourcesFound,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView.builder(
              itemCount: sources.length,
              itemBuilder: (context, index) {
                final source = sources[index];
                return SwitchListTile.adaptive(
                  title: Text(source.package),
                  subtitle: Text(
                    l10n.healthDashboardSourceRecordCount(source.count),
                  ),
                  value: source.enabled,
                  onChanged: state.isCollecting
                      ? null
                      : (value) => _toggle(context, source.package, value),
                );
              },
            ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    String package,
    bool enabled,
  ) async {
    final state = context.read<HealthDashboardState>();
    if (enabled) {
      await state.setSourceEnabled(type: type, package: package, enabled: true);
      return;
    }
    // Switching a source off deletes what it already contributed, across every
    // type, so it is worth confirming rather than silently dropping rows.
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ResponsiveAlertDialog(
        title: Text(package),
        content: Text(l10n.healthDashboardResetHealthConnectDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await state.setSourceEnabled(type: type, package: package, enabled: false);
  }
}
