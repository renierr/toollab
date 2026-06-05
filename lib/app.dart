import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/constants.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/pages/overview/overview_page.dart';
import 'package:tool_lab/pages/sync_settings_page.dart';
import 'package:tool_lab/pages/maintenance_page.dart';
import 'package:tool_lab/pages/shortcuts_settings_page.dart';
import 'package:tool_lab/services/shortcut_service.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/widgets/tool_chooser_dialog.dart';
import 'package:tool_lab/tools/calculator/calculator_page.dart';
import 'package:tool_lab/tools/bubble_level/bubble_level_page.dart';
import 'package:tool_lab/tools/emf_detector/emf_detector_page.dart';
import 'package:tool_lab/tools/device_info/device_info_page.dart';
import 'package:tool_lab/tools/nfc_tag_lab/nfc_tag_lab_page.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_viewer_page.dart';
import 'package:tool_lab/tools/notes/notes_page.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _navigatorKey,
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
        builder: (_, state) => _pageForTool(tool.id, state.extra),
      ),
    ),
  ],
);

Widget _pageForTool(String id, Object? extra) {
  return switch (id) {
    'calculator' => const CalculatorPage(),
    'bubble-level' => const BubbleLevelPage(),
    'emf-detector' => const EmfDetectorPage(),
    'device-info' => const DeviceInfoPage(),
    'nfc-tag-lab' => const NfcTagLabPage(),
    'pdf-viewer' => PdfViewerPage(sharedFile: extra as SharedFile?),
    'notes' => NotesPage(sharedFile: extra as SharedFile?),
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
  StreamSubscription<SharedFile>? _sharingSubscription;

  @override
  void initState() {
    super.initState();
    _initShortcuts();
    _initSharing();
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

  Future<void> _initSharing() async {
    final sharedFile = await SharingService.instance.getInitialSharedFile();
    if (sharedFile != null && mounted) {
      _handleSharedFile(sharedFile);
    }

    _sharingSubscription = SharingService.instance.onSharedFile.listen((file) {
      if (mounted) {
        _handleSharedFile(file);
      }
    });
  }

  Future<void> _handleSharedFile(SharedFile file) async {
    final matchingTools = SharingService.instance.getMatchingTools(file);
    if (matchingTools.isEmpty) {
      final context = _navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No tools found to open "${file.name}"')),
        );
      }
      return;
    }

    if (matchingTools.length == 1) {
      final tool = matchingTools.first;
      _router.go(tool.route, extra: file);
      return;
    }

    // Multiple matching tools: check default setting
    final defaultToolId = await SharingService.instance.getDefaultTool(
      file.mimeType,
    );
    if (defaultToolId != null) {
      final defaultTool = matchingTools.cast<ToolModel?>().firstWhere(
        (t) => t?.id == defaultToolId,
        orElse: () => null,
      );
      if (defaultTool != null) {
        _router.go(defaultTool.route, extra: file);
        return;
      }
    }

    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    final result = await showDialog<(ToolModel, bool)>(
      context: context,
      builder: (context) =>
          ToolChooserDialog(tools: matchingTools, fileName: file.name),
    );

    if (result != null) {
      final (selectedTool, remember) = result;
      if (remember) {
        await SharingService.instance.setDefaultTool(
          file.mimeType,
          selectedTool.id,
        );
      }
      _router.go(selectedTool.route, extra: file);
    }
  }

  @override
  void dispose() {
    _shortcutSubscription?.cancel();
    _sharingSubscription?.cancel();
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
