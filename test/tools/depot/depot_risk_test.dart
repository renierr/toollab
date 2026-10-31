import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/depot/depot_format.dart';
import 'package:tool_lab/tools/depot/depot_risk.dart';
import 'package:tool_lab/tools/depot/depot_xray.dart';
import 'package:tool_lab/tools/depot/models/depot_asset_profile.dart';
import 'package:tool_lab/tools/depot/models/depot_fund_constituent.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/models/depot_summary.dart';
import 'package:tool_lab/tools/depot/widgets/depot_risk_card.dart';

DepotHolding holding(
  String id,
  String name,
  double value, {
  String? isin,
  DepotAssetType type = DepotAssetType.security,
  bool sold = false,
}) => DepotHolding(
  id: id,
  portfolioId: id == 'fund' ? 'p2' : 'p1',
  name: name,
  isin: isin,
  assetType: type,
  shares: 1,
  purchasePrice: value,
  purchaseValue: value,
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

void main() {
  final alpha = holding('alpha', 'Alpha', 400, isin: 'AA');
  final fund = holding('fund', 'Global ETF', 300, isin: 'FUND');
  final beta = holding('beta', 'Beta', 200, isin: 'BB');
  final cash = holding('cash', 'Cash', 100, type: DepotAssetType.cash);
  final closed = holding('closed', 'Closed', 5000, sold: true);
  final holdings = [alpha, fund, beta, cash, closed];
  final profiles = <String, DepotAssetProfile>{
    'cash': DepotAssetProfile(
      country: 'USA',
      sector: 'Technology',
      fetchedAt: DateTime(2026),
    ),
    'alpha': DepotAssetProfile(
      country: 'USA',
      sector: 'Technology',
      fetchedAt: DateTime(2026),
    ),
    'beta': DepotAssetProfile(
      country: 'USA',
      sector: 'Technology',
      fetchedAt: DateTime(2026),
    ),
    'fund': DepotAssetProfile(
      kind: DepotHoldingKind.etf,
      countryShares: const {'USA': 0.6, 'Germany': 0.2},
      sectorShares: const {'Technology': 0.4, 'Healthcare': 0.2},
      constituents: const [
        DepotFundConstituent(name: 'Alpha', isin: 'AA', weight: 0.5),
        DepotFundConstituent(name: 'Gamma', isin: 'CC', weight: 0.2),
      ],
      fetchedAt: DateTime(2026),
    ),
  };
  DepotAssetProfile? profile(DepotHolding h) => profiles[h.id];
  final day = DepotChartPoint(
    date: DateTime(2026, 1, 1),
    value: 1000,
    capital: 1000,
    drawdown: 0,
  );

  test(
    'risk identifies positions and partial country and sector contributors',
    () {
      final risk = DepotRisk.calculate(holdings, [day], profileOf: profile);
      expect(risk.positions.map((p) => p.holding.name), [
        'Alpha',
        'Global ETF',
        'Beta',
      ]);
      expect(risk.topThree, 90);
      expect(risk.country.largest!.name, 'USA');
      expect(risk.country.largest!.weight, closeTo(78, 0.0001));
      expect(risk.country.largest!.contributors.map((c) => c.holding.name), [
        'Alpha',
        'Beta',
        'Global ETF',
      ]);
      expect(
        risk.country.largest!.contributors.last.weight,
        closeTo(18, 0.0001),
      );
      expect(risk.country.coverage, closeTo(84, 0.0001));
      expect(risk.country.missingWeight, closeTo(6, 0.0001));
      expect(risk.country.missingSecurities.single.holding.name, 'Global ETF');
      expect(risk.country.otherWeight, closeTo(10, 0.0001));
      expect(risk.country.otherAssets.single.holding.name, 'Cash');
      expect(risk.sector.largest!.name, 'Technology');
      expect(risk.sector.largest!.weight, closeTo(72, 0.0001));
      expect(risk.sector.coverage, closeTo(78, 0.0001));
      expect(risk.sector.missingWeight, closeTo(12, 0.0001));
      expect(risk.sector.otherWeight, closeTo(10, 0.0001));
      expect(risk.currentDrawdown, isNull);
      expect(risk.maxDrawdown, isNull);
    },
  );

  test('missing security data stays separate from other assets', () {
    final risk = DepotRisk.calculate(holdings, const []);
    expect(risk.country.largest, isNull);
    expect(risk.country.coverage, 0);
    expect(risk.country.missingWeight, 90);
    expect(risk.country.otherWeight, 10);
    expect(risk.sector.missingWeight, 90);
    expect(risk.sector.otherWeight, 10);
    final empty = DepotRisk.calculate([closed], const []);
    expect(empty.positions, isEmpty);
    expect(empty.country.coverage, 0);
    expect(empty.country.missingWeight, 0);
    expect(empty.country.otherWeight, 0);
  });

  test('rounding excess in fund weights does not invent missing coverage', () {
    final rounded = DepotAssetProfile(
      countryShares: const {'USA': 0.5003, 'Germany': 0.5003},
      fetchedAt: DateTime(2026),
    );
    final risk = DepotRisk.calculate(
      [fund],
      const [],
      profileOf: (_) => rounded,
    );
    expect(risk.country.coverage, closeTo(100, 0.0001));
    expect(risk.country.missingWeight, closeTo(0, 0.0001));
    expect(risk.country.otherWeight, 0);
  });

  for (final (width, scale) in [(320.0, 2.0), (1000.0, 1.0)]) {
    testWidgets('risk detail explains exposures at $width / $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final risk = DepotRisk.calculate(holdings, [day], profileOf: profile);
      final xray = depotXRay(
        holdings: holdings,
        profileOf: profile,
        kindOf: (h) => profile(h)?.kind ?? h.kind,
      );
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
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
              child: DepotRiskCard(
                risk: risk,
                format: DepotFormat('en', 'EUR'),
                xray: xray,
                periodLabel: 'Today',
                portfolioNames: const {'p1': 'Account A', 'p2': 'Account B'},
                onOpenAllocation: () => opened = true,
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Largest: Alpha (Account A)'), findsOneWidget);
      expect(find.text('Top three positions'), findsNothing);
      await tester.tap(find.text('Risk and concentration'));
      await tester.pumpAndSettle();
      expect(find.text('Top three positions'), findsOneWidget);
      expect(find.text('Global ETF'), findsOneWidget);
      expect(find.textContaining('Portfolio coverage: 84.00'), findsOneWidget);
      expect(find.textContaining('Portfolio coverage: 78.00'), findsOneWidget);
      await tester.ensureVisible(find.text('Largest known country'));
      await tester.tap(find.text('Largest known country'));
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsNWidgets(2));
      expect(find.text('Global ETF'), findsNWidgets(2));
      expect(
        find.textContaining('Missing security breakdowns · 6.00'),
        findsOneWidget,
      );
      expect(find.textContaining('Other asset types · 10.00'), findsOneWidget);
      await tester.ensureVisible(
        find.textContaining('Missing security breakdowns · 6.00'),
      );
      await tester.tap(
        find.textContaining('Missing security breakdowns · 6.00'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Global ETF'), findsNWidgets(3));
      await tester.ensureVisible(
        find.textContaining('Other asset types · 10.00'),
      );
      await tester.tap(find.textContaining('Other asset types · 10.00'));
      await tester.pumpAndSettle();
      expect(find.text('Cash'), findsOneWidget);
      await tester.ensureVisible(
        find.text('Largest known underlying holdings'),
      );
      await tester.tap(find.text('Largest known underlying holdings'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Via: Alpha (Account A), Global ETF (Account B)'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Value changes · Today'));
      await tester.tap(find.text('Value changes · Today'));
      await tester.pumpAndSettle();
      expect(
        find.text('Not enough chart data for this period.'),
        findsOneWidget,
      );
      expect(find.text('Current value drawdown'), findsNothing);
      await tester.ensureVisible(find.text('Open allocation'));
      await tester.tap(find.text('Open allocation'));
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
