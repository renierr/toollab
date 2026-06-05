import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/app.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/settings_service.dart';
import 'package:tool_lab/services/sharing_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  SharingService.startupArgs = args;
  await DatabaseService.instance.database;
  final settingsService = await SettingsService.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(settingsService),
      child: const ToolLabApp(),
    ),
  );
}
