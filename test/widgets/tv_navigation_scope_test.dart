import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/widgets/tv_navigation_scope.dart';

void main() {
  Future<void> pumpForm(WidgetTester tester, {required bool enabled}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvNavigationScope(
            enabled: enabled,
            child: Column(
              children: [
                const TextField(),
                ElevatedButton(onPressed: () {}, child: const Text('Next')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool fieldHasFocus(WidgetTester tester) {
    return tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode
        .hasFocus;
  }

  testWidgets('arrow down leaves a focused text field', (tester) async {
    await pumpForm(tester, enabled: true);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(fieldHasFocus(tester), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(fieldHasFocus(tester), isFalse);
  });

  testWidgets('without TV mode the field keeps the arrow keys', (tester) async {
    await pumpForm(tester, enabled: false);
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(fieldHasFocus(tester), isTrue);
  });
}
