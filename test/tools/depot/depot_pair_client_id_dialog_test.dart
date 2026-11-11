import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/depot/widgets/depot_pair_client_id_dialog.dart';

void main() {
  testWidgets('phone can enter and submit the client ID', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await DepotPairClientIdDialog.show(context, '');
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect with Parqet'));
    await tester.pumpAndSettle();
    expect(
      find.text("Enter the integration's client ID first."),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField), '  client-id  ');
    await tester.tap(find.text('Connect with Parqet'));
    await tester.pumpAndSettle();
    expect(result, 'client-id');
  });
}
