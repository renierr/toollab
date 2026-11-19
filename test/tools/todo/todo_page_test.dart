import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/l10n/app_localization_delegates.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/todo/todo_page.dart';
import 'package:tool_lab/tools/todo/todo_quick_parser.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';
import 'package:tool_lab/tools/todo/todo_view.dart';

void main() {
  late TodoState state;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  Future<void> pumpPage(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<TodoState>.value(
        value: state,
        child: MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          routerConfig: GoRouter(
            initialLocation: '/todo',
            routes: [
              GoRoute(path: '/todo', builder: (_, _) => const TodoPage()),
            ],
          ),
        ),
      ),
    );
    await tester.runAsync(() => state.load());
    await tester.pump();
  }

  testWidgets('renders lists, tasks and detail on phone and desktop', (
    tester,
  ) async {
    state = TodoState();
    await tester.runAsync(() async {
      await state.load();
      state.selectView(TodoView.smart(TodoSmartList.all));
      final now = DateTime.now();
      await state.addTask(
        TodoQuickDraft(
          title: 'A rather long task title that should wrap nicely on phones',
          due: now.add(const Duration(days: 1)),
          hasTime: true,
          important: true,
          tags: const ['home', 'errands'],
        ),
      );
      await state.addTask(const TodoQuickDraft(title: 'Second task'));
    });

    await pumpPage(tester, const Size(390, 800));
    expect(find.text('Second task'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Lists'));
    await tester.pumpAndSettle();
    expect(find.text('Important'), findsOneWidget);
    Navigator.of(tester.element(find.byType(Drawer))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    Navigator.of(tester.element(find.byType(Drawer))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Second task'));
    await tester.pumpAndSettle();
    expect(find.text('Add step'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpPage(tester, const Size(1400, 900));
    state.selectTask(state.openTasks(state.view).first.shortId);
    await tester.pump();
    expect(find.text('My Day'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick add parses and creates a task in the split layout', (
    tester,
  ) async {
    state = TodoState();
    await tester.runAsync(() => state.load());
    await pumpPage(tester, const Size(800, 700));
    await tester.enterText(
      find.byType(TextField).last,
      'Call plumber tomorrow 9:00 #house !',
    );
    await tester.pump();
    expect(find.text('house'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    final task = state.tasks.firstWhere((t) => t.title == 'Call plumber');
    expect(task.tags, ['house']);
    expect(task.important, isTrue);
    expect(task.dueHasTime, isTrue);
    expect(task.reminders, hasLength(1));
    expect(tester.takeException(), isNull);
    // Let the debounced sync run its (real) database reads to completion.
    await tester.pump(const Duration(seconds: 5));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(seconds: 11));
    }
    state.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
