import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';

import '../health_dashboard_state.dart';
import '../health_source_apps.dart';

/// Which writing apps a type is pulled from.
///
/// Per-type, unlike the global switch on the apps page: a republisher can be the
/// only writer for weight while being a redundant copy for heart rate, so the
/// choice has to be made per type rather than per app.
///
/// Switching one off is not destructive. It stops that writer being read for
/// this type and drops it out of the aggregates; the rows it already contributed
/// stay, so switching it back on costs nothing.
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
          : ListView(
              children: [
                SettingsSectionLabel(
                  title: l10n.healthDashboardDataSources,
                  description: l10n.healthDashboardDataSourcesHint,
                ),
                for (final source in sources)
                  SwitchListTile.adaptive(
                    secondary: Icon(healthAppIcon(source.package)),
                    title: Text(healthAppLabel(source.package, l10n)),
                    subtitle: Text(
                      l10n.healthDashboardSourceRecordCount(source.count),
                    ),
                    value: source.enabled,
                    onChanged: state.isCollecting
                        ? null
                        : (value) => context
                              .read<HealthDashboardState>()
                              .setSourceEnabled(
                                type: type,
                                package: source.package,
                                enabled: value,
                              ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
