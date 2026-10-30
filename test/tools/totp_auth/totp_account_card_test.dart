import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/totp_auth/totp.dart';
import 'package:tool_lab/tools/totp_auth/totp_account.dart';
import 'package:tool_lab/tools/totp_auth/widgets/totp_account_card.dart';

TotpAccount _account({TotpType type = TotpType.totp}) {
  return TotpAccount.newAccount(
    issuer: 'A very long service name that must not overflow',
    accountName: 'user@example.com',
    secret: 'JBSWY3DPEHPK3PXP',
    type: type,
  );
}

Future<void> _pump(
  WidgetTester tester,
  TotpAccount account, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 150 + (textScale - 1) * 34,
              child: TotpAccountCard(
                account: account,
                code: '123456',
                remaining: 20,
                onCopy: () {},
                onEdit: () {},
                onCopyUri: () {},
                onDelete: () {},
                onAdvance: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('card shows a grouped code without overflowing', (tester) async {
    await _pump(tester, _account());
    expect(find.text('123 456'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card fits when the text scale is doubled', (tester) async {
    await _pump(tester, _account(), textScale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('counter based account offers the next code action', (
    tester,
  ) async {
    await _pump(tester, _account(type: TotpType.hotp));
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
