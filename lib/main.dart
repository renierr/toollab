import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/app.dart';
import 'package:tool_lab/providers/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const ToolLabApp(),
    ),
  );
}
