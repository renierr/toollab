import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_dashboard_state.dart';

class HealthDayNavigation extends StatelessWidget {
  const HealthDayNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HealthDashboardState>();
    final l10n = AppLocalizations.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.center,
      children: [
        IconButton(
          tooltip: l10n.healthDashboardPreviousDay,
          onPressed: () =>
              context.read<HealthDashboardState>().previousTrendDay(),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        TextButton(
          onPressed: state.trendDayOffset == 0
              ? null
              : () => context.read<HealthDashboardState>().resetTrendDate(),
          child: Text(
            MaterialLocalizations.of(
              context,
            ).formatMediumDate(state.selectedDay),
          ),
        ),
        IconButton(
          tooltip: l10n.healthDashboardNextDay,
          onPressed: state.trendDayOffset == 0
              ? null
              : () => context.read<HealthDashboardState>().nextTrendDay(),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}
