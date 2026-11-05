import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/depot/depot_colors.dart';
import 'package:tool_lab/tools/depot/depot_format.dart';
import 'package:tool_lab/tools/depot/depot_portfolio_state.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/models/depot_summary.dart';
import 'package:tool_lab/tools/depot/widgets/depot_value_card.dart';
import 'package:tool_lab/tools/depot/widgets/depot_value_chart.dart';

import 'offline_test_support.dart';

void main() {
  blockDepotNetwork();
  for (final width in [320.0, 800.0]) {
    testWidgets(
      'today hides the chart and keeps a compact allocation at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final format = DepotFormat('de', 'EUR');
        final points = [
          DepotChartPoint(
            date: DateTime(2026, 10, 27),
            value: 100,
            capital: 90,
            drawdown: 0,
          ),
        ];

        Widget app(bool showChart) => MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DepotValueCard(
                points: points,
                change: const DepotRangeChange(valueChange: 10, gain: 8),
                allocation: const {DepotHoldingKind.stock: 100},
                format: format,
                showChart: showChart,
              ),
            ),
          ),
        );

        await tester.pumpWidget(app(false));
        expect(find.byType(DepotValueChart), findsNothing);
        expect(find.text('Diagramm anzeigen'), findsNothing);
        expect(find.textContaining('Veränderung'), findsOneWidget);
        expect(find.textContaining('Performance'), findsOneWidget);
        expect(find.text(format.money(100)), findsOneWidget);
        final segment = find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox &&
              widget.color == DepotColors.kind(DepotHoldingKind.stock),
        );
        expect(tester.getSize(segment).height, 14);
        final title = tester.getRect(find.text('Aufteilung'));
        final value = tester.getRect(find.text(format.money(100)));
        expect(value.top - title.bottom, lessThan(35));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(app(true));
        expect(find.byType(DepotValueChart), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('splits stocks and ETFs into 4 detailed allocation rows', (
    tester,
  ) async {
    final format = DepotFormat('de', 'EUR');
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DepotValueCard(
            points: const [],
            change: null,
            allocation: const {
              DepotHoldingKind.etfDistributing: 260,
              DepotHoldingKind.stockDividend: 250,
              DepotHoldingKind.stockGrowth: 140,
              DepotHoldingKind.etfAccumulating: 70,
            },
            format: format,
            showChart: false,
          ),
        ),
      ),
    );
    expect(find.text('ETFs (Ausschüttend)'), findsOneWidget);
    expect(find.text('Dividenden-Aktien'), findsOneWidget);
    expect(find.text('Aktien (ohne Dividende)'), findsOneWidget);
    expect(find.text('ETFs (Thesaurierend)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('detailed kind classifies distributing/accumulating and dividends', () {
    expect(
      DepotHoldingKind.etf.detailed(
        name: 'Vanguard FTSE All-World UCITS ETF - USD DIS',
        dividends: 0,
      ),
      DepotHoldingKind.etfDistributing,
    );
    expect(
      DepotHoldingKind.etf.detailed(
        name: 'VanEck Dividend Leaders UCITS ETF',
        dividends: 120,
      ),
      DepotHoldingKind.etfDistributing,
    );
    expect(
      DepotHoldingKind.etf.detailed(
        name: 'iShares Core MSCI EM IMI UCITS ETF - USD ACC',
        dividends: 0,
      ),
      DepotHoldingKind.etfAccumulating,
    );
    expect(
      DepotHoldingKind.stock.detailed(name: 'Microsoft', dividends: 480),
      DepotHoldingKind.stockDividend,
    );
    expect(
      DepotHoldingKind.stock.detailed(name: 'Tesla', dividends: 0),
      DepotHoldingKind.stockGrowth,
    );
  });
}
