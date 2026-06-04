import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/app.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/settings_service.dart';

void main() {
  testWidgets('App launches with overview page', (WidgetTester tester) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseService.instance.database;
    SharedPreferences.setMockInitialValues({});
    final settingsService = await SettingsService.init();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(settingsService),
        child: const ToolLabApp(),
      ),
    );
    expect(find.text('ToolLab'), findsWidgets);
  });
}
