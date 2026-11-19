import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/tools/code_highlight/code_highlight_state.dart';
import 'package:tool_lab/tools/code_highlight/widgets/code_highlight_editor.dart';

void main() {
  testWidgets('typing updates the code and an outside load syncs the editor', (
    tester,
  ) async {
    final state = CodeHighlightState()..setCode('a');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: CodeHighlightEditor())),
      ),
    );

    await tester.enterText(find.byType(TextField), 'x\ny\nz');
    await tester.pump();
    expect(state.code, 'x\ny\nz');
    expect(find.text('1\n2\n3'), findsOneWidget);

    state.loadFile('one\ntwo', 'f.dart', 'dart');
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'one\ntwo');
    expect(find.text('1\n2'), findsOneWidget);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
  });
}
