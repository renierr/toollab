import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/depot/depot_format.dart';
import 'package:tool_lab/tools/depot/depot_logo_state.dart';
import 'package:tool_lab/tools/depot/depot_portfolio_state.dart';
import 'package:tool_lab/tools/depot/depot_state.dart';
import 'package:tool_lab/tools/depot/models/depot_dividend_history.dart';
import 'package:tool_lab/tools/depot/models/depot_filters.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/models/depot_period.dart';
import 'package:tool_lab/tools/depot/models/depot_transaction.dart';
import 'package:tool_lab/tools/depot/widgets/depot_dividend_history_view.dart';
import 'package:tool_lab/tools/depot/widgets/depot_holding_details.dart';
import 'package:tool_lab/tools/depot/widgets/depot_movers_card.dart';
import 'package:tool_lab/tools/depot/widgets/depot_sales_summary.dart';

DepotTransaction tx(
  String id,
  DepotTransactionType type,
  DateTime date, {
  String currency = 'EUR',
  double amount = 100,
  double? gain,
  String portfolio = 'p',
  String holding = 'h',
}) => DepotTransaction(
  id: id,
  portfolioId: portfolio,
  holdingId: holding,
  holdingName: id,
  type: type,
  assetType: DepotAssetType.security,
  datetime: date,
  shares: 1,
  price: 1,
  amount: amount,
  amountNet: amount,
  tax: 0,
  fee: 0,
  currency: currency,
  realizedGain: gain,
);

class _PortfolioWithTransactions extends DepotPortfolioState {
  List<DepotTransaction> items = [];

  @override
  List<DepotTransaction> get transactions => items;

  void updateTransactions(List<DepotTransaction> value) {
    items = value;
    notifyListeners();
  }
}

void main() {
  test('dividend history isolates portfolio, year and currency', () {
    final history = DepotDividendHistory([
      tx('a', DepotTransactionType.dividend, DateTime(2026), amount: 10),
      tx(
        'b',
        DepotTransactionType.dividend,
        DateTime(2026),
        amount: 20,
        portfolio: 'other',
      ),
      tx(
        'c',
        DepotTransactionType.dividend,
        DateTime(2026),
        currency: 'usd',
        amount: 30,
      ),
      tx('d', DepotTransactionType.dividend, DateTime(2025), amount: 5),
      tx(
        'e',
        DepotTransactionType.dividend,
        DateTime(2026),
        currency: '',
        amount: 999,
      ),
      tx('f', DepotTransactionType.interest, DateTime(2026), amount: 800),
    ]);
    expect(history.totals[(2026, 'EUR')], 30);
    expect(history.totals[(2026, 'USD')], 30);
    expect(history.positions[(2026, 'EUR', 'p', 'h')], 10);
    expect(history.totals[(2025, 'EUR')], 5);
    expect(history.unknownCurrency, 1);
    expect(history.unknownByPosition[('p', 'h')], 1);
  });

  test('holding filter identifies portfolio and holding, not just name', () {
    final filter = DepotActivityFilter(
      portfolioId: 'p',
      holdingId: 'h',
      holdingName: 'Name',
      types: const {DepotTransactionType.sell},
    );
    expect(
      filter.matches(tx('one', DepotTransactionType.sell, DateTime(2026))),
      isTrue,
    );
    expect(
      filter.matches(
        tx(
          'two',
          DepotTransactionType.sell,
          DateTime(2026),
          portfolio: 'other',
        ),
      ),
      isFalse,
    );
    expect(
      filter.matches(
        tx('three', DepotTransactionType.dividend, DateTime(2026)),
      ),
      isFalse,
    );
    expect(filter.copyWith(clearHolding: true).holdingId, isNull);
  });

  testWidgets('sales and dividend history fit narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bookings = [
      tx('Gewinn', DepotTransactionType.sell, DateTime(2026), gain: 20),
      tx(
        'Verlust',
        DepotTransactionType.sell,
        DateTime(2026),
        currency: 'USD',
        gain: -10,
      ),
      tx('Unbekannt', DepotTransactionType.sell, DateTime(2026), gain: null),
      tx('Dividend', DepotTransactionType.dividend, DateTime(2026)),
      tx('Dividend', DepotTransactionType.dividend, DateTime(2025), amount: 50),
    ];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: ListView(
            children: [
              DepotSalesSummary(transactions: bookings, year: 2026),
              DepotDividendHistoryView(history: DepotDividendHistory(bookings)),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Verkäufe im Detail'));
    await tester.pumpAndSettle();
    expect(find.text('EUR'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(
      find.textContaining('Bei 1 Verkauf fehlt der Gewinn'),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.textContaining('zum Vorjahr'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sales summary separates largest gains and losses', (
    tester,
  ) async {
    final bookings = [
      tx('First gain', DepotTransactionType.sell, DateTime(2026, 1), gain: 20),
      tx('Bigger gain', DepotTransactionType.sell, DateTime(2026, 2), gain: 40),
      tx('Loss', DepotTransactionType.sell, DateTime(2026, 3), gain: -10),
    ];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(
            children: [DepotSalesSummary(transactions: bookings, year: 2026)],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Sales details'));
    await tester.pumpAndSettle();
    final gains = find.text('Largest gains · up to 3 sales');
    final losses = find.text('Largest losses · up to 3 sales');
    expect(gains, findsOneWidget);
    expect(losses, findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Bigger gain')).dy,
      lessThan(tester.getTopLeft(find.text('First gain')).dy),
    );
    expect(
      tester.getTopLeft(find.text('First gain')).dy,
      lessThan(tester.getTopLeft(losses).dy),
    );
    expect(
      tester.getTopLeft(losses).dy,
      lessThan(tester.getTopLeft(find.text('Loss')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'holding sales link selects exact holding and clears old filters',
    (tester) async {
      final portfolio = _PortfolioWithTransactions();
      final tabs = DepotState();
      addTearDown(portfolio.dispose);
      addTearDown(tabs.dispose);
      portfolio.setActivityFilter(const DepotActivityFilter(query: 'old'));
      const holding = DepotHolding(
        id: 'h',
        portfolioId: 'p',
        name: 'Holding',
        assetType: DepotAssetType.security,
        shares: 1,
        purchasePrice: 10,
        purchaseValue: 10,
        currentPrice: 15,
        currentValue: 15,
        isSold: false,
        unrealizedGain: 5,
        unrealizedReturn: 50,
        realizedGain: 2,
        dividends: 3,
        fees: 1,
        taxes: 1,
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DepotPortfolioState>.value(value: portfolio),
            ChangeNotifierProvider<DepotState>.value(value: tabs),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DepotHoldingDetails(
                  holding: holding,
                  performance: null,
                  period: DepotPeriod.max,
                  format: DepotFormat('en', 'EUR'),
                  weight: 0,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('+€10.00'), findsOneWidget);
      expect(find.text('Show sales'), findsNothing);
      portfolio.updateTransactions([
        tx('buy', DepotTransactionType.buy, DateTime(2026)),
        tx(
          'other',
          DepotTransactionType.sell,
          DateTime(2026),
          portfolio: 'other',
        ),
      ]);
      await tester.pump();
      expect(find.text('Show sales'), findsNothing);
      portfolio.updateTransactions([
        tx('sale', DepotTransactionType.sell, DateTime(2026)),
      ]);
      await tester.pump();
      await tester.ensureVisible(find.text('Show sales'));
      await tester.tap(find.text('Show sales'));
      expect(tabs.tab, DepotTab.activities);
      expect(portfolio.activityFilter.portfolioId, 'p');
      expect(portfolio.activityFilter.holdingId, 'h');
      expect(portfolio.activityFilter.types, {DepotTransactionType.sell});
      expect(portfolio.activityFilter.query, '');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('amount movers fit narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const holding = DepotHolding(
      id: 'h',
      portfolioId: 'p',
      name: 'A position',
      assetType: DepotAssetType.security,
      shares: 1,
      purchasePrice: 10,
      purchaseValue: 10,
      currentPrice: 15,
      currentValue: 15,
      isSold: false,
      unrealizedGain: 5,
      unrealizedReturn: 50,
      realizedGain: 2,
      dividends: 3,
      fees: 1,
      taxes: 1,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DepotLogoState(),
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              children: [
                DepotMoversCard(
                  movers: const [(holding: holding, returnPercent: 1234567.89)],
                  periodLabel: 'Jahr',
                  format: DepotFormat('de', 'EUR'),
                  byGain: true,
                  onModeChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
