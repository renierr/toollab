import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'health_dashboard_state.dart';
import 'widgets/health_dashboard_content.dart';
import 'widgets/health_dashboard_settings_page.dart';

class HealthDashboardPage extends StatefulWidget {
  const HealthDashboardPage({super.key});

  @override
  State<HealthDashboardPage> createState() => _HealthDashboardPageState();
}

class _HealthDashboardPageState extends State<HealthDashboardPage>
    with DisposeCleanup {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      if (!mounted) return;
      await context.read<HealthDashboardState>().refreshOnOpen();
    });
  }

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
              : () => context.read<HealthDashboardState>().refresh(),
          icon: state.isCollecting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync_rounded),
        ),
        IconButton(
          tooltip: l10n.healthDashboardSettings,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const HealthDashboardSettingsPage(),
            ),
          ),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      child: const HealthDashboardContent(),
    );
  }
}
