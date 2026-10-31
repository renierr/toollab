import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/depot/depot_allocation_state.dart';
import 'package:tool_lab/tools/depot/depot_benchmark_state.dart';
import 'package:tool_lab/tools/depot/depot_holding_trend_state.dart';
import 'package:tool_lab/tools/depot/depot_logo_state.dart';
import 'package:tool_lab/tools/depot/depot_portfolio_state.dart';
import 'package:tool_lab/tools/depot/depot_state.dart';
import 'package:tool_lab/tools/depot/models/depot_asset_profile.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/models/depot_period.dart';
import 'package:tool_lab/tools/depot/models/depot_portfolio.dart';
import 'package:tool_lab/tools/depot/models/depot_summary.dart';
import 'package:tool_lab/tools/depot/widgets/depot_benchmark_chart.dart';
import 'package:tool_lab/tools/depot/widgets/depot_movers_card.dart';
import 'package:tool_lab/tools/depot/widgets/depot_overview_view.dart';
import 'package:tool_lab/tools/depot/widgets/depot_risk_card.dart';
import 'package:tool_lab/tools/depot/widgets/depot_value_card.dart';

const _holding = DepotHolding(
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

class _Portfolio extends DepotPortfolioState {
  _Portfolio(this.selected);
  final DepotPeriod selected;

  @override
  bool get isLoaded => true;
  @override
  bool get isConnected => true;
  @override
  bool get hasData => true;
  @override
  DepotPeriod get period => selected;
  @override
  List<DepotHolding> get holdings => const [_holding];
  @override
  List<DepotHolding> get visibleHoldings => const [];
  @override
  List<DepotMover> get movers => const [
    (holding: _holding, returnPercent: 12.5),
  ];
  @override
  List<DepotChartPoint> get chart => selected == DepotPeriod.today
      ? const []
      : [
          DepotChartPoint(
            date: DateTime(2026, 1, 1),
            value: 10000,
            capital: 10000,
            drawdown: 0,
          ),
          DepotChartPoint(
            date: DateTime(2026, 1, 2),
            value: 20000,
            capital: 10000,
            drawdown: 0,
          ),
        ];
  @override
  DateTime? get lastSyncAt => DateTime(2026, 1, 1);
  @override
  List<DepotPortfolio> get portfolios => const [
    DepotPortfolio(
      id: 'p',
      name: 'A very long portfolio name for testing display',
      currency: 'EUR',
    ),
    DepotPortfolio(id: 'q', name: 'Second account', currency: 'EUR'),
  ];
}

class _Allocation extends DepotAllocationState {
  @override
  bool get isLoaded => true;
  @override
  DepotAssetProfile? profileOf(DepotHolding holding) => DepotAssetProfile(
    country: 'Germany',
    sector: 'Technology',
    fetchedAt: DateTime(2026),
  );
}

void main() {
  for (final scale in [1.0, 1.5, 2.0]) {
    for (final period in [DepotPeriod.today, DepotPeriod.month1]) {
      testWidgets('overview fits and orders cards at scale $scale, $period', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final portfolio = _Portfolio(period);
        final allocation = _Allocation();
        final benchmark = DepotBenchmarkState();
        final logo = DepotLogoState();
        final trend = DepotHoldingTrendState();
        final tabs = DepotState();
        addTearDown(portfolio.dispose);
        addTearDown(allocation.dispose);
        addTearDown(benchmark.dispose);
        addTearDown(logo.dispose);
        addTearDown(trend.dispose);
        addTearDown(tabs.dispose);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<DepotPortfolioState>.value(
                value: portfolio,
              ),
              ChangeNotifierProvider<DepotAllocationState>.value(
                value: allocation,
              ),
              ChangeNotifierProvider.value(value: benchmark),
              ChangeNotifierProvider.value(value: logo),
              ChangeNotifierProvider.value(value: trend),
              ChangeNotifierProvider.value(value: tabs),
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
              home: const Scaffold(body: DepotOverviewView()),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(DepotValueCard), findsOneWidget);
        expect(find.byType(DepotMoversCard), findsOneWidget);
        expect(find.byType(DepotRiskCard), findsOneWidget);
        expect(
          tester.getTopLeft(find.byType(DepotMoversCard)).dy,
          greaterThan(tester.getTopLeft(find.byType(DepotValueCard)).dy),
        );
        expect(
          tester.getTopLeft(find.byType(DepotRiskCard)).dy,
          greaterThan(tester.getTopLeft(find.byType(DepotMoversCard)).dy),
        );
        expect(
          find.byType(DepotBenchmarkChart),
          period == DepotPeriod.today ? findsNothing : findsOneWidget,
        );
        if (scale == 1 && period == DepotPeriod.today) {
          await tester.ensureVisible(find.byType(DepotRiskCard));
          await tester.tap(find.text('Risiko und Konzentration'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Aufteilung öffnen'));
          await tester.tap(find.text('Aufteilung öffnen'));
          expect(tabs.tab, DepotTab.allocation);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
