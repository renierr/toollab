import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localization_delegates.dart';
import 'package:tool_lab/tools/sqlite_viewer/sqlite_viewer_state.dart';
import 'package:tool_lab/tools/sqlite_viewer/widgets/sqlite_sql_editor.dart';

void main() {
  testWidgets('typing updates the SQL without notifying watchers', (
    tester,
  ) async {
    final state = SqliteViewerState();
    var notifications = 0;
    state.addListener(() => notifications++);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          home: Scaffold(body: SqliteSqlEditor(onRun: () {})),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'SELECT 1;\nSELECT 2;');
    await tester.pump();
    expect(state.sql, 'SELECT 1;\nSELECT 2;');
    expect(notifications, 0);
    expect(find.text('1\n2'), findsOneWidget);

    state.setSql('');
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
    expect(find.text('1'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(const SizedBox());
  });
}
