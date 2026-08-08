import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_dashboard_state.dart';
import 'health_source_badge.dart';

class HealthSourcePreferencesPage extends StatelessWidget {
  const HealthSourcePreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HealthDashboardState>();
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthDashboardSourcePreferences)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l10n.healthDashboardSourcePreferencesSubtitle),
          ),
          ..._types.map(
            (type) => _SourcePreferenceTile(
              title: _title(l10n, type),
              type: type,
              sources: state.availableSources(type),
              selected: state.preferredSource(type),
            ),
          ),
        ],
      ),
    );
  }

  static const _types = [
    'sleep.session',
    'activity.steps',
    'body.weight',
    'heart.resting',
    'heart.rate',
  ];

  String _title(AppLocalizations l10n, String type) => switch (type) {
    'sleep.session' => l10n.healthDashboardLastSleep,
    'activity.steps' => l10n.healthDashboardStepsToday,
    'body.weight' => l10n.healthDashboardWeight,
    'heart.resting' => l10n.healthDashboardRestingHeartRate,
    'heart.rate' => l10n.healthDashboardHeartRateTrend,
    _ => type,
  };
}

class _SourcePreferenceTile extends StatelessWidget {
  final String title;
  final String type;
  final List<String> sources;
  final String? selected;

  const _SourcePreferenceTile({
    required this.title,
    required this.type,
    required this.sources,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.tune_rounded),
      title: Text(title),
      subtitle: sources.isEmpty
          ? Text(l10n.healthDashboardNoData)
          : DropdownButton<String?>(
              value: selected?.isEmpty ?? true ? null : selected,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l10n.healthDashboardAnySource),
                ),
                ...sources.map(
                  (source) => DropdownMenuItem<String?>(
                    value: source,
                    child: HealthSourceBadge(packageName: source),
                  ),
                ),
              ],
              onChanged: (source) => context
                  .read<HealthDashboardState>()
                  .setPreferredSource(type, source),
            ),
    );
  }
}
