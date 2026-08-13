import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'health_dashboard_page.dart';
import 'health_dashboard_state.dart';
import 'health_sync_delegate.dart';

class HealthDashboardTool {
  HealthDashboardTool._();

  static ToolModel get config => ToolModel(
    id: 'health-dashboard',
    name: 'Health Dashboard',
    description: 'Bring your health data and workouts together',
    icon: Icons.monitor_heart_outlined,
    route: '/health-dashboard',
    accentColor: AppTheme.accentRed,
    sectionId: 'sensors',
    nameL10n: (l10n) => l10n.toolNameHealthDashboard,
    descriptionL10n: (l10n) => l10n.toolDescHealthDashboard,
    syncDelegateFactory: () => HealthSyncDelegate(),
    createPage: (_) => const HealthDashboardPage(),
    stateProviders: () => [
      ChangeNotifierProvider<HealthDashboardState>(
        create: (_) => HealthDashboardState(),
      ),
    ],
  );
}
