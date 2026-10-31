import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/depot/depot_benchmark_state.dart';
import 'package:tool_lab/tools/depot/depot_format.dart';
import 'package:tool_lab/tools/depot/depot_portfolio_state.dart';
import 'package:tool_lab/tools/depot/depot_risk.dart';
import 'package:tool_lab/tools/depot/depot_tax_export.dart';
import 'package:tool_lab/tools/depot/dividends/depot_dividend_calendar.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/models/depot_summary.dart';
import 'package:tool_lab/tools/depot/models/depot_transaction.dart';
import 'package:tool_lab/tools/depot/models/market_quote.dart';
import 'package:tool_lab/tools/depot/widgets/depot_benchmark_card.dart';
import 'package:tool_lab/tools/depot/widgets/depot_risk_card.dart';

DepotChartPoint point(int day, double value, double capital) => DepotChartPoint(
  date: DateTime(2026, 1, day),
  value: value,
  capital: capital,
  drawdown: 0,
);

DepotHolding holding(
  String name,
  double value, {
  DepotAssetType type = DepotAssetType.security,
  bool sold = false,
}) => DepotHolding(
  id: name,
  portfolioId: 'p',
  name: name,
  assetType: type,
  shares: 1,
  purchasePrice: 1,
  purchaseValue: 1,
  currentPrice: value,
  currentValue: value,
  isSold: sold,
  unrealizedGain: 0,
  unrealizedReturn: 0,
  realizedGain: 0,
  dividends: 0,
  fees: 0,
  taxes: 0,
);

class _Portfolio extends DepotPortfolioState {
  @override
  final List<DepotChartPoint> chart = [point(1, 100, 100), point(2, 110, 100)];
}

void main() {
  test('risk ignores sold positions and tracks value drawdown', () {
    final risk = DepotRisk.calculate(
      [
        holding('a', 60),
        holding('b', 30, type: DepotAssetType.crypto),
        holding('c', 10),
        holding('sold', 1000, sold: true),
      ],
      [point(1, 100, 100), point(2, 80, 100), point(3, 90, 100)],
    );
    expect(risk.topOne, 60);
    expect(risk.topThree, 100);
    expect(risk.crypto, 30);
    expect(risk.maxDrawdown, closeTo(-20, 0.001));
    expect(risk.currentDrawdown, closeTo(-10, 0.001));
    expect(risk.bestDay, closeTo(12.5, 0.001));
  });

  test('comparison removes capital changes and aligns by previous close', () {
    final result = compareDepotBenchmark(
      [point(1, 100, 100), point(2, 160, 150), point(3, 176, 150)],
      [
        MarketPricePoint(date: DateTime(2026, 1, 1), close: 10),
        MarketPricePoint(date: DateTime(2026, 1, 3), close: 12),
      ],
    );
    expect(result.length, 3);
    expect(result[1].portfolio, closeTo(110, 0.001));
    expect(result[1].benchmark, 100);
    expect(result.last.portfolio, closeTo(121, 0.001));
    expect(result.last.benchmark, 120);
  });

  test('old benchmark requests cannot replace a newer selection', () async {
    final requests = <Completer<MarketQuote>>[];
    final state = DepotBenchmarkState(
      loader: (_, _, _) {
        final request = Completer<MarketQuote>();
        requests.add(request);
        return request.future;
      },
    );
    addTearDown(state.dispose);
    final chart = [point(1, 100, 100), point(2, 110, 100)];
    MarketQuote quote(double end) => MarketQuote(
      price: end,
      previousClose: 10,
      currency: 'EUR',
      exchange: '',
      points: [
        MarketPricePoint(date: DateTime(2026, 1, 1), close: 10),
        MarketPricePoint(date: DateTime(2026, 1, 2), close: end),
      ],
    );
    state.select(DepotBenchmark.world);
    final first = state.load(chart, 'EUR');
    state.select(DepotBenchmark.sp500);
    final second = state.load(chart, 'EUR');
    requests[1].complete(quote(12));
    await second;
    requests[0].complete(quote(20));
    await first;
    expect(state.points.last.benchmark, 120);
    await state.load(chart, 'USD');
    expect(state.currencyMismatch, isTrue);
    expect(requests, hasLength(2));
  });

  test('tax CSV selects year, escapes text and retains currencies', () {
    DepotTransaction transaction(int year) => DepotTransaction(
      id: '$year',
      portfolioId: 'p',
      holdingId: 'h',
      holdingName: '=bad,"name"',
      type: DepotTransactionType.dividend,
      assetType: DepotAssetType.security,
      datetime: DateTime(year, 1, 1),
      shares: 1,
      price: 2,
      amount: 3,
      amountNet: 2,
      tax: 1,
      fee: 0,
      currency: 'USD',
    );
    final text = utf8.decode(
      DepotTaxExport.csv([transaction(2025), transaction(2026)], 2026),
    );
    expect(text, contains('"\'=bad,""name"""'));
    expect(text, contains('"USD"'));
    expect(text, isNot(contains('2025-01-01')));
  });

  test('yield on cost does not mix booking currencies', () {
    final h = holding('asset', 100);
    DepotTransaction dividend(String currency) => DepotTransaction(
      id: 'dividend',
      portfolioId: h.portfolioId,
      holdingId: h.id,
      type: DepotTransactionType.dividend,
      assetType: DepotAssetType.security,
      datetime: DateTime(2026, 1, 1),
      shares: 1,
      price: 0,
      amount: 5,
      amountNet: 4,
      tax: 1,
      fee: 0,
      currency: currency,
    );
    DepotDividendPosition position(String currency) =>
        DepotDividendCalendar.build(
          holdings: [h],
          transactions: [dividend(currency)],
          assets: const {},
          currency: 'EUR',
          now: DateTime(2026, 2, 1),
        ).positions.single;
    expect(position('EUR').yieldOnCost, 400);
    expect(position('USD').yieldOnCost, isNull);
  });

  testWidgets('insight cards fit a narrow screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final benchmark = DepotBenchmarkState(
      loader: (_, _, _) async => MarketQuote(
        price: 12,
        previousClose: 10,
        currency: 'EUR',
        exchange: '',
        points: [
          MarketPricePoint(date: DateTime(2026, 1, 1), close: 10),
          MarketPricePoint(date: DateTime(2026, 1, 2), close: 12),
        ],
      ),
    )..select(DepotBenchmark.world);
    final portfolio = _Portfolio();
    await benchmark.load(portfolio.chart, 'EUR');
    addTearDown(benchmark.dispose);
    addTearDown(portfolio.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: benchmark),
          ChangeNotifierProvider<DepotPortfolioState>.value(value: portfolio),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              children: [
                const DepotBenchmarkCard(),
                DepotRiskCard(
                  risk: DepotRisk.calculate(
                    [holding('asset', 100)],
                    [point(1, 100, 100), point(2, 80, 100)],
                  ),
                  format: DepotFormat('en', 'EUR'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
