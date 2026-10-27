import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/depot/depot_colors.dart';
import 'package:tool_lab/tools/depot/depot_format.dart';
import 'package:tool_lab/tools/depot/models/depot_income_month.dart';
import 'package:tool_lab/tools/depot/widgets/depot_income_chart.dart';

import 'offline_test_support.dart';

void main() {
  blockDepotNetwork();
  test('monthly median includes empty months and averages the middle pair', () {
    List<DepotIncomeMonth> months(List<double> totals) => [
      for (var i = 0; i < totals.length; i++)
        DepotIncomeMonth(
          month: DateTime(2026, i + 1),
          dividends: totals[i],
          interest: 0,
        ),
    ];
    expect(DepotIncomeMonth.medianTotal([]), 0);
    expect(DepotIncomeMonth.medianTotal(months([100, 0, 20])), 20);
    expect(DepotIncomeMonth.medianTotal(months([100, 0, 20, 40])), 30);
    expect(DepotIncomeMonth.medianTotal(months([0, 100, 0, 0])), 0);
  });

  for (final width in [320.0, 800.0, 1440.0]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('readable labels at width $width, scale $textScale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final months = [
          for (var i = 0; i < 12; i++)
            DepotIncomeMonth(
              month: DateTime(2026, i + 1),
              dividends: 123.45 + i * 200,
              interest: 6.78,
            ),
        ];
        final format = DepotFormat('de', 'EUR');
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('de'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: DepotIncomeChart(months: months, format: format),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(FittedBox), findsNothing);
        for (final month in months) {
          expect(find.text(format.money(month.total)), findsOneWidget);
        }
        expect(find.text(format.axisMoney(0)), findsOneWidget);
        expect(find.text('Median ${format.money(1230.23)}'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('income-median-line')),
          findsOneWidget,
        );
        final monthLabel = tester.widget<Text>(
          find.text(DateFormat.MMM('de').format(months.first.month)),
        );
        expect(monthLabel.style!.fontSize, 11);
        final bars = find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox &&
              widget.color == DepotColors.dividendBooked,
        );
        expect(bars, findsNWidgets(12));
        expect(tester.getSize(bars.first).width, 36);
        final horizontal = find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        );
        await tester.drag(horizontal, const Offset(-2000, 0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
