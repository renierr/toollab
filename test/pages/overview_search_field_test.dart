import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/pages/overview/overview_search_field.dart';

void main() {
  Future<void> pumpField(WidgetTester tester, {required bool tv}) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: OverviewSearchField(
            controller: controller,
            onChanged: (_) {},
            keyboardOnActivate: tv,
          ),
        ),
      ),
    );
  }

  void focusField(WidgetTester tester) {
    final field = tester.widget<TextField>(find.byType(TextField));
    field.focusNode!.requestFocus();
  }

  testWidgets('TV: focus leaves the keyboard closed, OK opens it', (
    tester,
  ) async {
    await pumpField(tester, tv: true);
    focusField(tester);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
  });

  testWidgets('elsewhere focus opens the keyboard as usual', (tester) async {
    await pumpField(tester, tv: false);
    focusField(tester);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
  });
}
