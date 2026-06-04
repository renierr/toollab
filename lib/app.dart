import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/constants.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/pages/overview/overview_page.dart';
import 'package:tool_lab/pages/calculator/calculator_page.dart';
import 'package:tool_lab/pages/bubble_level/bubble_level_page.dart';
import 'package:tool_lab/pages/emf_detector/emf_detector_page.dart';
import 'package:tool_lab/pages/device_info/device_info_page.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'overview',
      builder: (_, _) => const OverviewPage(),
    ),
    GoRoute(
      path: '/calculator',
      name: 'calculator',
      builder: (_, _) => const CalculatorPage(),
    ),
    GoRoute(
      path: '/bubble-level',
      name: 'bubble-level',
      builder: (_, _) => const BubbleLevelPage(),
    ),
    GoRoute(
      path: '/emf-detector',
      name: 'emf-detector',
      builder: (_, _) => const EmfDetectorPage(),
    ),
    GoRoute(
      path: '/device-info',
      name: 'device-info',
      builder: (_, _) => const DeviceInfoPage(),
    ),
  ],
);

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
