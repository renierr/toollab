import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/depot/depot_format.dart';
import 'package:tool_lab/tools/depot/depot_logo_state.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/widgets/depot_movers_card.dart';

class _LogoState extends Fake implements DepotLogoState {
  @override
  Uint8List? bytesFor(String key) => null;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

void main() {
  const holding = DepotHolding(
    id: '1',
    portfolioId: 'portfolio',
    name: 'A very long company name that will be truncated',
    assetType: DepotAssetType.security,
    isin: 'DE0000000001',
    shares: 2.5,
    purchasePrice: 40,
    purchaseValue: 100,
    currentPrice: 50,
    currentValue: 125,
    isSold: false,
    unrealizedGain: 25,
    unrealizedReturn: 25,
    realizedGain: 0,
    dividends: 0,
    fees: 0,
    taxes: 0,
  );

  testWidgets('copies the card after its pending paint', (tester) async {
    var copied = false;
    await tester.pumpWidget(
      ChangeNotifierProvider<DepotLogoState>.value(
        value: _LogoState(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DepotMoversCard(
              movers: const [(holding: holding, returnPercent: 3.5)],
              periodLabel: 'Today',
              format: DepotFormat('en', 'EUR'),
              captureAndCopy: (boundary, pixelRatio) async {
                expect(boundary.debugNeedsPaint, isFalse);
                copied = true;
                return true;
              },
            ),
          ),
        ),
      ),
    );
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find
          .ancestor(
            of: find.byType(Card),
            matching: find.byType(RepaintBoundary),
          )
          .first,
    );
    boundary.markNeedsPaint();
    await tester.tap(find.byTooltip('Copy as image'));
    await tester.pumpAndSettle();
    expect(copied, isTrue);
    expect(find.text('Movers copied to clipboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not capture after the card is removed', (tester) async {
    var captured = false;
    await tester.pumpWidget(
      ChangeNotifierProvider<DepotLogoState>.value(
        value: _LogoState(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DepotMoversCard(
              movers: const [(holding: holding, returnPercent: 3.5)],
              periodLabel: 'Today',
              format: DepotFormat('en', 'EUR'),
              captureAndCopy: (boundary, pixelRatio) async {
                captured = true;
                return true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Copy as image'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(captured, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mover mode chips use compact height and switch modes', (
    tester,
  ) async {
    bool? selected;
    await tester.pumpWidget(
      ChangeNotifierProvider<DepotLogoState>.value(
        value: _LogoState(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                DepotMoversCard(
                  movers: const [(holding: holding, returnPercent: 3.5)],
                  periodLabel: 'Today',
                  format: DepotFormat('en', 'EUR'),
                  onModeChanged: (value) => selected = value,
                ),
                const ChoiceChip(
                  key: ValueKey('default-chip'),
                  label: Text('Contribution'),
                  selected: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final chip = find.descendant(
      of: find.byType(DepotMoversCard),
      matching: find.widgetWithText(ChoiceChip, 'Contribution'),
    );
    final standardChip = find.byKey(const ValueKey('default-chip'));
    expect(
      tester.getSize(chip).height,
      lessThan(tester.getSize(standardChip).height),
    );
    expect(
      tester.getSize(chip).width,
      lessThan(tester.getSize(standardChip).width),
    );
    expect(tester.widget<ChoiceChip>(chip).showCheckmark, isFalse);
    await tester.tap(chip);
    expect(selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['en', 'de']) {
    testWidgets('mover tooltip works on touch and hover in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final format = DepotFormat(locale, 'EUR');

      await tester.pumpWidget(
        ChangeNotifierProvider<DepotLogoState>.value(
          value: _LogoState(),
          child: MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DepotMoversCard(
                movers: const [(holding: holding, returnPercent: 3.5)],
                periodLabel: locale == 'en' ? 'Today' : 'Heute',
                format: format,
              ),
            ),
          ),
        ),
      );

      final rowTooltip = find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip && widget.triggerMode == TooltipTriggerMode.tap,
      );
      final tooltip = tester.widget<Tooltip>(rowTooltip);
      final message = tooltip.message!;
      expect(message, contains(holding.name));
      expect(message, contains(holding.isin));
      expect(message, contains(format.shares(holding.shares)));
      expect(message, contains(format.money(holding.currentPrice)));
      expect(message, contains(format.money(holding.currentValue)));
      expect(message, contains(format.percent(3.5)));
      expect(
        message,
        contains(locale == 'en' ? 'Current value' : 'Aktueller Wert'),
      );

      await tester.tap(rowTooltip);
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(seconds: 9));
      expect(find.text(message), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(rowTooltip));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
    });
  }
}
