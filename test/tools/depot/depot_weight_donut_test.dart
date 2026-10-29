import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/depot/depot_format.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/widgets/depot_weight_donut.dart';

DepotHolding holding(String id, double value, {bool sold = false}) =>
    DepotHolding.fromJson('p', {
      'id': id,
      'asset': {'type': 'security', 'name': id, 'symbol': id},
      'position': {'currentValue': value, 'isSold': sold},
    });

void main() {
  testWidgets('fits a narrow screen and totals open positive positions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(180, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final format = DepotFormat('en', 'EUR');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DepotWeightDonut(
            holdings: [
              holding('A', 75),
              holding('B', 25),
              holding('C', 200, sold: true),
            ],
            format: format,
          ),
        ),
      ),
    );
    expect(find.text(format.money(100)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'hover and tap show the correct slice and clear outside the ring',
    (tester) async {
      final format = DepotFormat('en', 'EUR');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DepotWeightDonut(
              holdings: [holding('A', 75), holding('B', 25)],
              format: format,
            ),
          ),
        ),
      );
      final chart = find.byType(DepotWeightDonut);
      final center = tester.getCenter(chart);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: center + const Offset(100, 0));
      await mouse.moveTo(center + const Offset(100, 0));
      await tester.pump();
      expect(find.text('A'), findsOneWidget);
      expect(find.text(format.percent(75, signed: false)), findsOneWidget);
      expect(find.text(format.money(75)), findsOneWidget);
      await mouse.moveTo(center + const Offset(-100, 0));
      await tester.pump();
      expect(find.text('B'), findsOneWidget);
      expect(find.text(format.percent(25, signed: false)), findsOneWidget);
      await mouse.moveTo(center);
      await tester.pump();
      expect(find.text(format.money(100)), findsOneWidget);
      await mouse.removePointer();
      await tester.tapAt(center + const Offset(-100, 0));
      await tester.pump();
      expect(find.text('B'), findsOneWidget);
    },
  );

  testWidgets('selected details fit a narrow chart with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(180, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(180, 400),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: DepotWeightDonut(
              holdings: [holding('A very long holding name', 100)],
              format: DepotFormat('en', 'EUR'),
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(
      tester.getCenter(find.byType(DepotWeightDonut)) + const Offset(80, 0),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
