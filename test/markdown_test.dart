import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/widgets/markdown_checkbox.dart';
import 'package:tool_lab/widgets/markdown_view.dart';

void main() {
  testWidgets('Test Case 1: Checklist with unindented text block in between', (
    WidgetTester tester,
  ) async {
    const data = '''
- [ ] ed e
- [ ] eded ed

efvevf

- [ ] jzzjjz
''';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MarkdownView(data: data)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownCheckbox), findsNWidgets(3));
    expect(find.text('ed e'), findsOneWidget);
    expect(find.text('eded ed'), findsOneWidget);
    expect(find.text('efvevf'), findsOneWidget);
    expect(find.text('jzzjjz'), findsOneWidget);
  });

  testWidgets(
    'Test Case 2: Checklist separated by single blank line splits lists',
    (WidgetTester tester) async {
      const data = '''
- [ ] ed e
- [ ] eded ed

- [ ] jzzjjz
''';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MarkdownView(data: data)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MarkdownCheckbox), findsNWidgets(3));
      expect(find.text('ed e'), findsOneWidget);
      expect(find.text('eded ed'), findsOneWidget);
      expect(find.text('jzzjjz'), findsOneWidget);

      final listColumns = find.descendant(
        of: find.byType(MarkdownView),
        matching: find.byType(Column),
      );
      expect(listColumns.evaluate().length, greaterThanOrEqualTo(2));
    },
  );

  testWidgets(
    'Test Case 3: Checklist separated by multiple blank lines splits lists and renders spacing',
    (WidgetTester tester) async {
      const data = '''
- [ ] ed e
- [ ] eded ed



- [ ] jzzjjz
''';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MarkdownView(data: data)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MarkdownCheckbox), findsNWidgets(3));
      expect(find.text('ed e'), findsOneWidget);
      expect(find.text('eded ed'), findsOneWidget);
      expect(find.text('jzzjjz'), findsOneWidget);
      expect(find.textContaining('\u00a0'), findsWidgets);

      final listColumns = find.descendant(
        of: find.byType(MarkdownView),
        matching: find.byType(Column),
      );
      expect(listColumns.evaluate().length, greaterThanOrEqualTo(2));
    },
  );

  testWidgets('Test Case 4: Code block with long line does not throw errors', (
    WidgetTester tester,
  ) async {
    const data = '''
```
This is an extremely long line in a code block that should definitely overflow the screen width and be scrollable horizontally.
```
''';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MarkdownView(data: data)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('overflow the screen width'), findsOneWidget);
  });
}
