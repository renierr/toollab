import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:tool_lab/app.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/background_task_service.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/settings_service.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/theme/theme.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  SharingService.startupArgs = args;
  runApp(const ToolLabBootstrap());
}

/// Renders a splash immediately and moves startup I/O (temp dir, database,
/// settings, background tasks) behind the first frame so slow storage or a
/// failure at boot never leaves the user on a blank screen.
class ToolLabBootstrap extends StatefulWidget {
  const ToolLabBootstrap({super.key});

  @override
  State<ToolLabBootstrap> createState() => _ToolLabBootstrapState();
}

class _ToolLabBootstrapState extends State<ToolLabBootstrap> {
  AppState? _appState;
  List<SingleChildWidget>? _toolProviders;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      // The temp dir and the database are independent round trips to storage,
      // so they run together instead of adding up.
      final settingsFuture = DatabaseService.instance.database.then(
        (_) => SettingsService.init(),
      );
      await TempFileManager.init();
      final settingsService = await settingsFuture;
      final toolProviders = ToolRegistry.all
          .map((t) => t.stateProviders)
          .where((f) => f != null)
          .expand((f) => f!())
          .toList();
      unawaited(BackgroundTaskService.init());
      if (!mounted) return;
      setState(() {
        _appState = AppState(settingsService);
        _toolProviders = toolProviders;
      });
    } catch (e) {
      errorLog('[Bootstrap] Startup failed: $e');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = _appState;
    if (appState == null) {
      // The stored theme lives in the database that is still opening, so the
      // splash follows the platform brightness — which is also the app default.
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: _BootstrapSplash(error: _error),
      );
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ...?_toolProviders,
      ],
      child: const ToolLabApp(),
    );
  }
}

/// Shown while startup I/O runs, and turned into the failure message if it
/// throws. Cannot be localized — the locale is loaded by the work it waits on.
class _BootstrapSplash extends StatelessWidget {
  final Object? error;

  const _BootstrapSplash({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: error != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: theme.colorScheme.error,
                      size: 40,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Startup failed: $error',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.science_outlined,
                      size: 48,
                      color: AppTheme.accentBlue,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: AppTheme.accentBlue,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
