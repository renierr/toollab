import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/depot/depot_format.dart';
import 'package:tool_lab/tools/depot/depot_dividend_state.dart';
import 'package:tool_lab/tools/depot/depot_logo_state.dart';
import 'package:tool_lab/tools/depot/dividends/depot_dividend_calendar.dart';
import 'package:tool_lab/tools/depot/models/depot_dividend.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/models/depot_income_month.dart';
import 'package:tool_lab/tools/depot/models/depot_transaction.dart';
import 'package:tool_lab/tools/depot/widgets/depot_dividend_calendar_card.dart';
import 'package:tool_lab/tools/depot/widgets/depot_dividend_entry_tile.dart';
import 'package:tool_lab/tools/depot/widgets/depot_dividend_kpis.dart';
import 'package:tool_lab/tools/depot/widgets/depot_dividend_missing_card.dart';
import 'package:tool_lab/tools/depot/widgets/depot_dividend_positions_card.dart';
import 'package:tool_lab/tools/depot/widgets/depot_dividend_year_chart.dart';
import 'package:tool_lab/tools/depot/widgets/depot_income_chart.dart';

void main() {
  for (final scale in [1.0, 1.3, 1.5, 2.0]) {
    testWidgets('dividend entry fits at text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final logos = DepotLogoState();
      addTearDown(logos.dispose);
      final entry = DepotDividendEntry(
        name: 'Example holding',
        colorSeed: 'example',
        date: DateTime(2026, 8, 3),
        gross: 123.45,
        net: 98.76,
        status: DepotDividendStatus.booked,
        holding: null,
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: logos,
          child: MaterialApp(
            locale: const Locale('de'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: ListView(
                children: [
                  DepotDividendEntryTile(
                    entry: entry,
                    format: DepotFormat('de', 'EUR'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('dividend cards fit at text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final logos = DepotLogoState();
      final dividends = DepotDividendState();
      addTearDown(logos.dispose);
      addTearDown(dividends.dispose);
      final now = DateTime.now();
      const holding = DepotHolding(
        id: 'asset',
        portfolioId: 'p',
        name: 'Example holding',
        assetType: DepotAssetType.security,
        isin: 'DE0000000001',
        shares: 100,
        purchasePrice: 100,
        purchaseValue: 10000,
        currentPrice: 200,
        currentValue: 20000,
        isSold: false,
        unrealizedGain: 10000,
        unrealizedReturn: 100,
        realizedGain: 0,
        dividends: 0,
        fees: 0,
        taxes: 0,
      );
      final transactions = [
        for (var year = now.year - 11; year <= now.year; year++)
          DepotTransaction(
            id: '$year',
            portfolioId: 'p',
            holdingId: holding.id,
            type: DepotTransactionType.dividend,
            assetType: DepotAssetType.security,
            datetime: DateTime(year, now.month, 1),
            shares: 100,
            price: 0,
            amount: 1234567.89,
            amountNet: 987654.32,
            tax: 246913.57,
            fee: 0,
            currency: 'EUR',
          ),
      ];
      final asset = DepotDividendAsset(
        key: holding.isin!,
        symbol: 'EXAMPLE',
        currency: 'EUR',
        fxCurrency: 'EUR',
        fxRate: 1,
        fetchedAt: now,
        events: [
          DepotDividendEvent(
            exDate: now.subtract(const Duration(days: 60)),
            amount: 2,
          ),
        ],
      );
      final calendar = DepotDividendCalendar.build(
        holdings: [holding],
        transactions: transactions,
        assets: {holding.isin!: asset},
        currency: 'EUR',
        now: now,
      );
      final format = DepotFormat('de', 'EUR');
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: logos),
            ChangeNotifierProvider.value(value: dividends),
          ],
          child: MaterialApp(
            locale: const Locale('de'),
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
                    DepotDividendKpis(calendar: calendar, format: format),
                    DepotDividendMissingCard(
                      entries: calendar.missing,
                      format: format,
                    ),
                    DepotDividendCalendarCard(
                      calendar: calendar,
                      format: format,
                    ),
                    DepotDividendYearChart(calendar: calendar, format: format),
                    DepotIncomeChart(
                      months: [
                        for (var i = 0; i < 12; i++)
                          DepotIncomeMonth(
                            month: DateTime(now.year, i + 1),
                            dividends: 987654.32,
                            interest: 0,
                          ),
                      ],
                      format: format,
                    ),
                    DepotDividendPositionsCard(
                      positions: calendar.positions,
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
    });
  }
}
