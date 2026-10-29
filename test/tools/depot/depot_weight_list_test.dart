import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/depot/depot_colors.dart';
import 'package:tool_lab/tools/depot/depot_format.dart';
import 'package:tool_lab/tools/depot/depot_logo_state.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/widgets/depot_weight_list.dart';

class _Logos extends DepotLogoState {
  @override
  Future<void> ensureLoaded() async {}
}

DepotHolding _holding(String symbol, double value) =>
    DepotHolding.fromJson('p', {
      'id': symbol,
      'asset': {'type': 'security', 'name': symbol, 'symbol': symbol},
      'position': {'currentValue': value},
    });

void main() {
  testWidgets('holding bars have height and scale with position value', (
    tester,
  ) async {
    final logos = _Logos();
    addTearDown(logos.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<DepotLogoState>.value(
        value: logos,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DepotWeightList(
              holdings: [_holding('A', 100), _holding('B', 50)],
              format: DepotFormat('en', 'EUR'),
            ),
          ),
        ),
      ),
    );
    Finder bar(int index) => find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color ==
              DepotColors.weight(index, 2),
    );
    final first = tester.getSize(bar(0));
    final second = tester.getSize(bar(1));
    expect(first.height, 4);
    expect(second.height, 4);
    expect(second.width, closeTo(first.width / 2, 0.01));
    expect(tester.takeException(), isNull);
  });
}
