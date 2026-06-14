import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rhttp/rhttp.dart';
import 'package:tool_lab/app.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/settings_service.dart';
import 'package:tool_lab/services/sharing_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Rhttp.init();
  await TempFileManager.init();
  SharingService.startupArgs = args;
  await DatabaseService.instance.database;
  final settingsService = await SettingsService.init();

  final toolProviders = ToolRegistry.all
      .map((t) => t.stateProviders)
      .where((f) => f != null)
      .expand((f) => f!())
      .toList();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState(settingsService)),
        ...toolProviders,
      ],
      child: const ToolLabApp(),
    ),
  );
}
