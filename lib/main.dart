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
      await TempFileManager.init();
      await DatabaseService.instance.database;
      final settingsService = await SettingsService.init();
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
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Startup failed: $_error'),
                  ),
                )
              : const Center(child: CircularProgressIndicator()),
        ),
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
