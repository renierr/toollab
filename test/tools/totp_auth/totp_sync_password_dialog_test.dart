import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/totp_auth/widgets/totp_sync_password_dialog.dart';

void main() {
  testWidgets('sync password dialog scrolls above the keyboard', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);

    TotpSyncPasswordResult? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await TotpSyncPasswordDialog.show(
                  context,
                  current: 'existing password',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final dialog = find.byType(TotpSyncPasswordDialog);
    final scroll = find.descendant(
      of: dialog,
      matching: find.byType(SingleChildScrollView),
    );
    expect(scroll, findsOneWidget);
    final save = find.text('Save');
    expect(
      tester.getRect(scroll).bottom,
      lessThanOrEqualTo(tester.getRect(save).top),
    );
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(300));

    await tester.drag(scroll, const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'new password');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(result?.password, 'new password');
    expect(tester.takeException(), isNull);
  });
}
