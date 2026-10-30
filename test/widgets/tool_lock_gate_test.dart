import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/tool_lock_controller.dart';
import 'package:tool_lab/widgets/tool_lock_gate.dart';

class _Controller extends ToolLockController {
  _Controller() : super(toolId: 'test', envelopeSetting: 'key') {
    initialized = true;
  }

  @override
  bool get configured => true;

  @override
  bool get canReset => attempts >= 5;

  @override
  bool get supportsBiometric => false;

  void fail() {
    attempts++;
    notifyListeners();
  }
}

void main() {
  testWidgets('password form scrolls above a small-screen keyboard', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    final controller = _Controller();
    addTearDown(controller.dispose);
    var entered = '';
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ToolLockGate(
            controller: controller,
            setup: (_) async {},
            unlock: (password) async {
              entered = password;
              return false;
            },
            unlockBiometric: () async => false,
            reset: () async {},
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'password');
    await tester.ensureVisible(find.text('Unlock'));
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(entered, 'password');
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset is shown after five failures and requires confirmation', (
    tester,
  ) async {
    final controller = _Controller();
    addTearDown(controller.dispose);
    var resets = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ToolLockGate(
            controller: controller,
            setup: (_) async {},
            unlock: (_) async {
              controller.fail();
              return false;
            },
            unlockBiometric: () async => false,
            reset: () async {
              resets++;
            },
          ),
        ),
      ),
    );
    expect(find.text('Reset local data'), findsNothing);
    for (var i = 0; i < 5; i++) {
      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Reset local data'), findsOneWidget);
    await tester.tap(find.text('Reset local data'));
    await tester.pumpAndSettle();
    expect(resets, 0);
    await tester.tap(find.text('Delete local data'));
    await tester.pumpAndSettle();
    expect(resets, 1);
    expect(tester.takeException(), isNull);
  });
}
