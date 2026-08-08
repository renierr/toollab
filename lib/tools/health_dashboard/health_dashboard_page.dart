import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'health_dashboard_state.dart';
import 'widgets/health_dashboard_content.dart';

class HealthDashboardPage extends StatelessWidget {
  const HealthDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<HealthDashboardState>();
    return ToolLayout(
      title: l10n.toolNameHealthDashboard,
      actions: [
        IconButton(
          tooltip: l10n.healthDashboardRefresh,
          onPressed: state.isCollecting
              ? null
              : () => context.read<HealthDashboardState>().collect(),
          icon: state.isCollecting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync_rounded),
        ),
      ],
      child: const HealthDashboardContent(),
    );
  }
}
