import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/constants.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/pages/overview/overview_page.dart';
import 'package:tool_lab/pages/sync_settings_page.dart';
import 'package:tool_lab/pages/maintenance_page.dart';
import 'package:tool_lab/pages/shortcuts_settings_page.dart';
import 'package:tool_lab/pages/about_page.dart';
import 'package:tool_lab/pages/appearance_settings_page.dart';
import 'package:tool_lab/pages/sync_stats_page.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/services/shortcut_service.dart';
import 'package:tool_lab/core/app_route_observer.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/widgets/tool_chooser_dialog.dart';
import 'package:tool_lab/tools/gps_location_store/gps_info_page.dart';
import 'package:tool_lab/tools/treadmill_control/treadmill_history_page.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_settings_page.dart';
import 'package:tool_lab/tools/text_editor/widgets/text_editor_settings_page.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _navigatorKey,
  observers: [appRouteObserver],
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/text-editor/settings',
      name: 'text-editor-settings',
      builder: (_, _) => const TextEditorSettingsPage(),
    ),
    GoRoute(
      path: '/file-manager/settings',
      name: 'file-manager-settings',
      builder: (_, _) => const FileManagerSettingsPage(),
    ),
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
      path: '/sync-stats',
      name: 'sync-stats',
      builder: (_, _) => const SyncStatsPage(),
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
    GoRoute(
      path: '/appearance-settings',
      name: 'appearance-settings',
      builder: (_, _) => const AppearanceSettingsPage(),
    ),
    GoRoute(
      path: '/about',
      name: 'about',
      builder: (_, _) => const AboutPage(),
    ),
    GoRoute(
      path: '/gps-location-store/gps-info',
      name: 'gps-info',
      builder: (_, _) => const GpsInfoPage(),
    ),
    GoRoute(
      path: '/treadmill-control/history',
      name: 'treadmill-history',
      builder: (_, _) => const TreadmillHistoryPage(),
    ),
    ...ToolRegistry.all.map(
      (tool) => GoRoute(
        path: tool.route,
        name: tool.id,
        builder: (_, state) => _pageForTool(tool.id, state.extra),
      ),
    ),
  ],
);

Widget _pageForTool(String id, Object? extra) {
  final tool = ToolRegistry.all.where((t) => t.id == id).firstOrNull;
  if (tool != null) return tool.createPage(extra as SharedData?);
  return const OverviewPage();
}

class ToolLabApp extends StatefulWidget {
  const ToolLabApp({super.key});

  @override
  State<ToolLabApp> createState() => _ToolLabAppState();
}

class _ToolLabAppState extends State<ToolLabApp> with WidgetsBindingObserver {
  StreamSubscription<String>? _shortcutSubscription;
  StreamSubscription<SharedData>? _sharingSubscription;
  String? _lastSharedFilePath;
  DateTime? _lastSharedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initShortcuts();
    _initSharing();
  }

  Future<void> _initShortcuts() async {
    final launchRoute = await ShortcutService.instance.getLaunchRoute();
    if (launchRoute != null && launchRoute != '/' && mounted) {
      _router.go(launchRoute);
    }

    _shortcutSubscription = ShortcutService.instance.onShortcutRoute.listen((
      route,
    ) {
      if (!mounted) return;
      if (route == '/') {
        if (!_router.canPop() && _router.state.matchedLocation != '/') {
          _router.go('/');
        }
      } else {
        _router.go(route);
      }
    });
  }

  Future<void> _initSharing() async {
    final sharedData = await SharingService.instance.getInitialSharedData();
    if (sharedData != null && !sharedData.isEmpty && mounted) {
      _handleSharedData(sharedData);
    }

    _sharingSubscription = SharingService.instance.onSharedData.listen((data) {
      if (mounted && !data.isEmpty) {
        _handleSharedData(data);
      }
    });
  }

  Future<void> _handleSharedData(SharedData data) async {
    await SharingService.instance.clearSharedData();
    final firstFile = data.firstFile;
    if (firstFile == null) return;

    final now = DateTime.now();
    if (_lastSharedFilePath == firstFile.path &&
        _lastSharedTime != null &&
        now.difference(_lastSharedTime!) < const Duration(seconds: 2)) {
      return;
    }
    _lastSharedFilePath = firstFile.path;
    _lastSharedTime = now;

    final matchingTools = SharingService.instance.getMatchingTools(firstFile);
    if (matchingTools.isEmpty) {
      final context = _navigatorKey.currentContext;
      if (context != null && context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.coreNoToolsFoundToOpen(firstFile.name))),
        );
      }
      return;
    }

    if (matchingTools.length == 1) {
      final tool = matchingTools.first;
      _router.go(tool.route, extra: data);
      return;
    }

    // Multiple matching tools: check default setting
    final defaultToolId = await SharingService.instance.getDefaultTool(
      firstFile.mimeType,
    );
    if (defaultToolId != null) {
      final defaultTool = matchingTools.cast<ToolModel?>().firstWhere(
        (t) => t?.id == defaultToolId,
        orElse: () => null,
      );
      if (defaultTool != null) {
        _router.go(defaultTool.route, extra: data);
        return;
      }
    }

    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    final result = await showDialog<(ToolModel, bool)>(
      context: context,
      builder: (context) =>
          ToolChooserDialog(tools: matchingTools, fileName: firstFile.name),
    );

    if (result != null) {
      final (selectedTool, remember) = result;
      if (remember) {
        await SharingService.instance.setDefaultTool(
          firstFile.mimeType,
          selectedTool.id,
        );
      }
      _router.go(selectedTool.route, extra: data);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shortcutSubscription?.cancel();
    _sharingSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingSharing();
    } else if (state == AppLifecycleState.detached) {
      TempFileManager.cleanSession();
    }
  }

  Future<void> _checkPendingSharing() async {
    final sharedData = await SharingService.instance.getInitialSharedData();
    if (sharedData != null && !sharedData.isEmpty && mounted) {
      _handleSharedData(sharedData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return MaterialApp.router(
      scrollBehavior: const AppScrollBehavior(),
      title: AppConstants.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: appState.themeMode,
      locale: appState.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
