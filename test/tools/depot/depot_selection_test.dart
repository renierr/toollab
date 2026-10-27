import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/depot/depot_format.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/models/depot_period.dart';
import 'package:tool_lab/tools/depot/widgets/depot_holding_details.dart';

import 'offline_test_support.dart';

void main() {
  blockDepotNetwork();
  testWidgets('long press copies an ISIN on Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Center(child: SelectionArea(child: Text('US0378331005'))),
        ),
      ),
    );
    await tester.longPress(find.text('US0378331005'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kopieren'));
    await tester.pumpAndSettle();
    expect(copied, 'US0378331005');
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('holding ISIN and values can be selected and copied', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    const holding = DepotHolding(
      id: '1',
      portfolioId: '1',
      name: 'Apple',
      assetType: DepotAssetType.security,
      isin: 'US0378331005',
      shares: 2,
      purchasePrice: 40,
      purchaseValue: 80,
      currentPrice: 50,
      currentValue: 100,
      isSold: false,
      unrealizedGain: 20,
      unrealizedReturn: 25,
      realizedGain: 0,
      dividends: 0,
      fees: 0,
      taxes: 0,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SelectionArea(
            child: DepotHoldingDetails(
              holding: holding,
              period: DepotPeriod.today,
              format: DepotFormat('de', 'EUR'),
              performance: null,
              weight: 100,
            ),
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    for (final value in ['US0378331005', DepotFormat('de', 'EUR').money(50)]) {
      copied = null;
      final bounds = tester.getRect(find.text(value));
      await mouse.down(bounds.centerLeft + const Offset(1, 0));
      await mouse.moveTo(bounds.centerRight - const Offset(1, 0));
      await mouse.up();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(copied, value);
    }
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });
}
