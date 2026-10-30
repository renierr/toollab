import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/tool_lock_controller.dart';
import 'package:tool_lab/widgets/tool_lock_settings_dialog.dart';

class _Controller extends ToolLockController {
  _Controller() : super(toolId: 'test', envelopeSetting: 'key') {
    biometric = true;
    automatic = true;
  }

  @override
  bool get supportsBiometric => true;

  @override
  Future<void> setBiometricTimeout(int minutes) async {
    biometricTimeoutMinutes = minutes;
    notifyListeners();
  }
}

void main() {
  testWidgets('biometric timeout is configurable on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _Controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ToolLockSettingsDialog(controller: controller)),
      ),
    );
    expect(
      find.text('Open without unlocking bypasses device authentication.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('After 15 min').last);
    await tester.pumpAndSettle();
    expect(controller.biometricTimeoutMinutes, 15);
    expect(tester.takeException(), isNull);
  });
}
