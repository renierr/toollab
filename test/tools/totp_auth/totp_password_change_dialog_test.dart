import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/tools/totp_auth/widgets/totp_password_change_dialog.dart';

void main() {
  testWidgets('password change validates and submits on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? current;
    String? password;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TotpPasswordChangeDialog(
            adopt: false,
            submit: (oldValue, newValue) async {
              current = oldValue;
              password = newValue;
            },
          ),
        ),
      ),
    );
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), 'old password');
    await tester.enterText(fields.at(1), 'new password');
    await tester.enterText(fields.at(2), 'different');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(current, isNull);
    await tester.enterText(fields.at(2), 'new password');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(current, 'old password');
    expect(password, 'new password');
    expect(tester.takeException(), isNull);
  });

  testWidgets('backend mismatch leaves the update dialog open', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TotpPasswordChangeDialog(
            adopt: true,
            submit: (_, _) async => throw const SyncPasswordMismatchException(),
          ),
        ),
      ),
    );
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'wrong password');
    await tester.enterText(fields.at(1), 'wrong password');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Update sync password'), findsOneWidget);
    expect(
      find.textContaining('does not match the backend data'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
