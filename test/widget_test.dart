import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/app.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/settings_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  testWidgets('App launches with overview page', (WidgetTester tester) async {
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
