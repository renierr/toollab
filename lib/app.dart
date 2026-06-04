import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/constants.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/pages/overview/overview_page.dart';
import 'package:tool_lab/tools/calculator/calculator_page.dart';
import 'package:tool_lab/tools/bubble_level/bubble_level_page.dart';
import 'package:tool_lab/tools/emf_detector/emf_detector_page.dart';
import 'package:tool_lab/tools/device_info/device_info_page.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'overview',
      builder: (_, _) => const OverviewPage(),
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
    _ => const OverviewPage(),
  };
}

class ToolLabApp extends StatelessWidget {
  const ToolLabApp({super.key});

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
