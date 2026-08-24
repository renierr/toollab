import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/app_route_observer.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'health_dashboard_state.dart';
import 'widgets/health_dashboard_content.dart';
import 'widgets/health_dashboard_settings_page.dart';

class HealthDashboardPage extends StatefulWidget {
  const HealthDashboardPage({super.key});

  @override
  State<HealthDashboardPage> createState() => _HealthDashboardPageState();
}

class _HealthDashboardPageState extends State<HealthDashboardPage>
    with DisposeCleanup, RouteAware {
  @override
  void initState() {
    super.initState();
    onDispose(() => appRouteObserver.unsubscribe(this));
    Future<void>.microtask(() async {
      if (!mounted) return;
      await context.read<HealthDashboardState>().refreshOnOpen(
        backendSync: _backendSync(),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  /// The dashboard stays alive underneath a pushed screen, so an import or a
  /// sync run over there leaves this page painting what it read on open.
  @override
  void didPopNext() {
    context.read<HealthDashboardState>().reloadStoredData();
  }

  /// Health Connect and the backend in one action. The backend step is handed
  /// in as a closure so the tool's state never reaches for [AppState] - and it
  /// is left out entirely when this tool has no delegate registered, which is
  /// also what the global switch being off looks like from here.
  Future<void> Function()? _backendSync() {
    final appState = context.read<AppState>();
    final delegates = appState.syncDelegates
        .where((delegate) => delegate.toolId == HealthDashboardTool.config.id)
        .toList();
    if (delegates.isEmpty) return null;
    return () => appState.syncWithBackend(delegates);
  }

  Future<void> _refresh() {
    return context.read<HealthDashboardState>().refresh(
      backendSync: _backendSync(),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const HealthDashboardSettingsPage(),
      ),
    );
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
          onPressed: state.isCollecting ? null : _refresh,
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
          onPressed: _openSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      child: HealthDashboardContent(onRefresh: _refresh),
    );
  }
}
