import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localization_delegates.dart';
import 'package:tool_lab/tools/weather/api/mosmix_client.dart';
import 'package:tool_lab/tools/weather/weather_settings.dart';
import 'package:tool_lab/tools/weather/weather_units.dart';
import 'package:tool_lab/tools/weather/widgets/weather_trend_chart.dart';
import 'package:tool_lab/widgets/health_chart_tooltip.dart';

void main() {
  final hours = MosmixClient.parseKmz(
    File('test/fixtures/weather/mosmix_L841.kmz').readAsBytesSync(),
    'L841',
  ).hours.take(48).toList();

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: const [Locale('en'), Locale('de')],
      locale: const Locale('de'),
      home: Scaffold(
        body: SizedBox(
          width: 600,
          child: WeatherTrendChart(
            hours: hours,
            metric: WeatherTrendMetric.temperature,
            units: const WeatherUnits(WeatherSettings()),
            dayLabel: (t) => '${t.day}',
          ),
        ),
      ),
    ),
  );

  testWidgets('tap shows the hour readout and it hides by itself', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(HealthChartTooltip), findsNothing);
    await tester.tapAt(tester.getCenter(find.byType(WeatherTrendChart)));
    await tester.pump();
    expect(find.byType(HealthChartTooltip), findsOneWidget);
    expect(find.textContaining('Temperatur'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(HealthChartTooltip), findsNothing);
  });

  testWidgets('dragging follows the finger', (tester) async {
    await pump(tester);
    final chart = tester.getRect(find.byType(WeatherTrendChart));
    final gesture = await tester.startGesture(
      chart.centerLeft + const Offset(60, 0),
    );
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    final first = tester.getTopLeft(find.byType(HealthChartTooltip));
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byType(HealthChartTooltip)).dx,
      greaterThan(first.dx),
    );
    await gesture.up();
    await tester.pump(const Duration(seconds: 4));
  });
}
