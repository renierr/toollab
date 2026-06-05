import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/constants.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/pages/overview/overview_page.dart';
import 'package:tool_lab/pages/sync_settings_page.dart';
import 'package:tool_lab/pages/maintenance_page.dart';
import 'package:tool_lab/pages/shortcuts_settings_page.dart';
import 'package:tool_lab/services/shortcut_service.dart';
import 'package:tool_lab/tools/calculator/calculator_page.dart';
import 'package:tool_lab/tools/bubble_level/bubble_level_page.dart';
import 'package:tool_lab/tools/emf_detector/emf_detector_page.dart';
import 'package:tool_lab/tools/device_info/device_info_page.dart';
import 'package:tool_lab/tools/nfc_tag_lab/nfc_tag_lab_page.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'overview',
      builder: (_, _) => const OverviewPage(),
    ),
    GoRoute(
      path: '/sync-settings',
      name: 'sync-settings',
      builder: (_, _) => const SyncSettingsPage(),
    ),
    GoRoute(
      path: '/maintenance',
      name: 'maintenance',
      builder: (_, _) => const MaintenancePage(),
    ),
    GoRoute(
      path: '/shortcut-settings',
      name: 'shortcut-settings',
      builder: (_, _) => const ShortcutsSettingsPage(),
    ),
    ...ToolRegistry.all.map(
      (tool) => GoRoute(
        path: tool.route,
        name: tool.id,
        builder: (_, _) => _pageForTool(tool.id),
      ),
    ),
  ],
);

Widget _pageForTool(String id) {
  return switch (id) {
    'calculator' => const CalculatorPage(),
    'bubble-level' => const BubbleLevelPage(),
    'emf-detector' => const EmfDetectorPage(),
    'device-info' => const DeviceInfoPage(),
    'nfc-tag-lab' => const NfcTagLabPage(),
    _ => const OverviewPage(),
  };
}

class ToolLabApp extends StatefulWidget {
  const ToolLabApp({super.key});

  @override
  State<ToolLabApp> createState() => _ToolLabAppState();
}

class _ToolLabAppState extends State<ToolLabApp> {
  StreamSubscription<String>? _shortcutSubscription;

  @override
  void initState() {
    super.initState();
    _initShortcuts();
  }

  Future<void> _initShortcuts() async {
    final launchRoute = await ShortcutService.instance.getLaunchRoute();
    if (launchRoute != null && mounted) {
      _router.go(launchRoute);
    }

    _shortcutSubscription = ShortcutService.instance.onShortcutRoute.listen((
      route,
    ) {
      if (mounted) {
        _router.go(route);
      }
    });
  }

  @override
  void dispose() {
    _shortcutSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: appState.themeMode,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
