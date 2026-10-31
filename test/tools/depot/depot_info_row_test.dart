import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/depot/depot_format.dart';
import 'package:tool_lab/tools/depot/depot_holding_trend_state.dart';
import 'package:tool_lab/tools/depot/depot_logo_state.dart';
import 'package:tool_lab/tools/depot/depot_xray.dart';
import 'package:tool_lab/tools/depot/dividends/depot_dividend_calendar.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/models/depot_fund_constituent.dart';
import 'package:tool_lab/tools/depot/models/depot_period.dart';
import 'package:tool_lab/tools/depot/models/depot_transaction.dart';
import 'package:tool_lab/tools/depot/widgets/depot_dividend_entry_tile.dart';
import 'package:tool_lab/tools/depot/widgets/depot_transaction_tile.dart';
import 'package:tool_lab/tools/depot/widgets/depot_xray_card.dart';
import 'package:tool_lab/tools/depot/widgets/depot_holding_tile.dart';
import 'package:tool_lab/tools/depot/widgets/depot_weight_row.dart';

const holding = DepotHolding(
  id: 'asset',
  portfolioId: 'p',
  name: 'Example holding',
  assetType: DepotAssetType.security,
  shares: 10,
  purchasePrice: 100,
  purchaseValue: 1000,
  currentPrice: 200,
  currentValue: 2000,
  isSold: false,
  unrealizedGain: 1000,
  unrealizedReturn: 100,
  realizedGain: 0,
  dividends: 0,
  fees: 0,
  taxes: 0,
);

void main() {
  for (final width in [320.0, 1000.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'dividend, X-Ray and activity rows fit and align at $width / $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final logos = DepotLogoState();
          addTearDown(logos.dispose);
          final format = DepotFormat('en', 'EUR');
          final entry = DepotDividendEntry(
            holding: holding,
            name: holding.name,
            colorSeed: holding.id,
            date: DateTime(2026, 11, 14),
            gross: 150.46,
            net: 116.53,
            status: DepotDividendStatus.upcoming,
          );
          const xray = DepotXRay(
            total: 10000000000,
            uncovered: 2000000000,
            hasLookThrough: true,
            entries: [
              DepotXRayEntry(
                key: 'company',
                name: 'Tesla',
                value: 882000000,
                sources: [
                  DepotXRaySource(
                    holding: holding,
                    kind: DepotHoldingKind.stock,
                    value: 882000000,
                  ),
                ],
              ),
            ],
          );
          final transaction = DepotTransaction(
            id: 't',
            portfolioId: 'p',
            holdingId: holding.id,
            type: DepotTransactionType.dividend,
            assetType: DepotAssetType.security,
            datetime: DateTime(2026),
            shares: 10,
            price: 2,
            amount: 150,
            amountNet: 116,
            tax: 34,
            fee: 0,
            currency: 'EUR',
            holdingName: holding.name,
          );
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: logos,
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: Column(
                      children: [
                        DepotDividendEntryTile(entry: entry, format: format),
                        DepotXRayCard(xray: xray, format: format),
                        DepotTransactionTile(
                          transaction: transaction,
                          format: format,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          final dividendRight = tester
              .getRect(find.byType(DepotDividendEntryTile))
              .right;
          final amountRight = tester
              .getRect(find.text(format.money(entry.net)))
              .right;
          expect(dividendRight - amountRight, closeTo(8, 0.1));
          final tileRight = tester.getRect(find.byType(ExpansionTile)).right;
          final valueRight = tester
              .getRect(find.text(format.money(882000000)))
              .right;
          expect(tileRight - valueRight, closeTo(8, 0.1));
          await tester.tap(find.text('Tesla'));
          await tester.pumpAndSettle();
          expect(find.text('Example holding'), findsWidgets);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('holding and allocation rows fit large values at $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final logos = DepotLogoState();
      final trends = DepotHoldingTrendState();
      addTearDown(logos.dispose);
      addTearDown(trends.dispose);
      const big = DepotHolding(
        id: 'large',
        portfolioId: 'p',
        name: 'Large fund',
        assetType: DepotAssetType.security,
        shares: 100,
        purchasePrice: 10000,
        purchaseValue: 1000000,
        currentPrice: 12345678,
        currentValue: 1234567890,
        isSold: false,
        unrealizedGain: 1000,
        unrealizedReturn: 10,
        realizedGain: 0,
        dividends: 0,
        fees: 0,
        taxes: 0,
      );
      final format = DepotFormat('en', 'EUR');
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: logos),
            ChangeNotifierProvider.value(value: trends),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    DepotHoldingTile(
                      holding: big,
                      performance: null,
                      period: DepotPeriod.today,
                      format: format,
                      weight: 100,
                    ),
                    DepotWeightRow(
                      holding: big,
                      kind: DepotHoldingKind.fund,
                      share: 1,
                      barFraction: 1,
                      barColor: Colors.blue,
                      format: format,
                      constituents: const [
                        DepotFundConstituent(
                          name: 'Fund component',
                          weight: 0.9,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(DepotWeightRow));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
