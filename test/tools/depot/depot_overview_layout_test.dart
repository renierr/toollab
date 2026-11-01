import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/depot/depot_allocation_state.dart';
import 'package:tool_lab/tools/depot/depot_benchmark_state.dart';
import 'package:tool_lab/tools/depot/depot_holding_trend_state.dart';
import 'package:tool_lab/tools/depot/depot_logo_state.dart';
import 'package:tool_lab/tools/depot/depot_portfolio_state.dart';
import 'package:tool_lab/tools/depot/depot_state.dart';
import 'package:tool_lab/tools/depot/depot_store.dart';
import 'package:tool_lab/tools/depot/models/depot_asset_profile.dart';
import 'package:tool_lab/tools/depot/models/depot_filters.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/models/depot_period.dart';
import 'package:tool_lab/tools/depot/models/depot_portfolio.dart';
import 'package:tool_lab/tools/depot/models/depot_summary.dart';
import 'package:tool_lab/tools/depot/widgets/depot_benchmark_chart.dart';
import 'package:tool_lab/tools/depot/widgets/depot_movers_card.dart';
import 'package:tool_lab/tools/depot/widgets/depot_overview_view.dart';
import 'package:tool_lab/tools/depot/widgets/depot_risk_card.dart';
import 'package:tool_lab/tools/depot/widgets/depot_value_card.dart';

import 'offline_test_support.dart';

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
  blockDepotNetwork();
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
    FlutterSecureStorage.setMockInitialValues({});
    await DepotStore.instance.clear();
  });
  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

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

  testWidgets('custom holding sort persists order and shows drag handles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = DepotStore.instance;
    const h1 = DepotHolding(
      id: 'h1',
      portfolioId: 'p',
      name: 'Alpha Holding',
      assetType: DepotAssetType.security,
      shares: 10,
      purchasePrice: 100,
      purchaseValue: 1000,
      currentPrice: 150,
      currentValue: 1500,
      isSold: false,
      unrealizedGain: 500,
      unrealizedReturn: 50,
      realizedGain: 0,
      dividends: 0,
      fees: 0,
      taxes: 0,
    );
    const h2 = DepotHolding(
      id: 'h2',
      portfolioId: 'p',
      name: 'Beta Holding',
      assetType: DepotAssetType.security,
      shares: 10,
      purchasePrice: 100,
      purchaseValue: 1000,
      currentPrice: 120,
      currentValue: 1200,
      isSold: false,
      unrealizedGain: 200,
      unrealizedReturn: 20,
      realizedGain: 0,
      dividends: 0,
      fees: 0,
      taxes: 0,
    );

    final portfolio = DepotPortfolioState();
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

    await tester.runAsync(() async {
      await store.clear();
      await store.savePerformance(
        portfolios: const [
          DepotPortfolio(id: 'p', name: 'Main', currency: 'EUR'),
        ],
        holdings: const [h1, h2],
        summaries: [
          DepotSummary(
            scope: DepotStore.allScope,
            period: DepotPeriod.today,
            currency: 'EUR',
            valueStart: 2000,
            valueEnd: 2700,
            unrealizedGain: 700,
            unrealizedReturn: 35,
            realizedGain: 0,
            dividends: 0,
            fees: 0,
            taxes: 0,
            syncedAt: DateTime(2026, 1, 1),
          ),
        ],
        charts: const {},
        holdingPerformance: const [],
      );
      await portfolio.ensureLoaded();
    });
    expect(portfolio.visibleHoldings.map((h) => h.id), ['h1', 'h2']);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DepotPortfolioState>.value(value: portfolio),
          ChangeNotifierProvider<DepotAllocationState>.value(value: allocation),
          ChangeNotifierProvider.value(value: benchmark),
          ChangeNotifierProvider.value(value: logo),
          ChangeNotifierProvider.value(value: trend),
          ChangeNotifierProvider.value(value: tabs),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DepotOverviewView()),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.drag_handle), findsNothing);

    await tester.runAsync(() async {
      portfolio.setHoldingFilter(
        portfolio.holdingFilter.copyWith(sort: DepotHoldingSort.custom),
      );
    });
    await tester.pump();
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));

    await tester.runAsync(() => portfolio.reorderHolding(0, 1));
    await tester.pump();
    expect(portfolio.visibleHoldings.map((h) => h.id), ['h2', 'h1']);
    expect(await tester.runAsync(store.holdingOrder), {'p/h2': 0, 'p/h1': 1});

    final reloaded = DepotPortfolioState();
    addTearDown(reloaded.dispose);
    await tester.runAsync(reloaded.ensureLoaded);
    expect(reloaded.holdingFilter.sort, DepotHoldingSort.custom);
    expect(reloaded.visibleHoldings.map((h) => h.id), ['h2', 'h1']);
  });
}
