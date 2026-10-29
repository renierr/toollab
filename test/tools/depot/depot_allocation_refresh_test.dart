import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/depot/depot_allocation_state.dart';
import 'package:tool_lab/tools/depot/depot_portfolio_state.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/widgets/depot_allocation_refresh_button.dart';

class _Portfolio extends DepotPortfolioState {
  final done = Completer<void>();
  bool busy = false;
  int calls = 0;
  List<DepotHolding> current = [];

  @override
  bool get isLoaded => true;
  @override
  bool get isConnected => true;
  @override
  bool get isSyncing => busy;
  @override
  List<DepotHolding> get holdings => current;

  @override
  Future<void> sync({bool full = false}) async {
    calls++;
    busy = true;
    notifyListeners();
    await done.future;
    current = [
      DepotHolding.fromJson('p', {
        'id': 'new',
        'asset': {'type': 'security', 'name': 'New'},
        'position': {'currentValue': 100},
      }),
    ];
    busy = false;
    notifyListeners();
  }
}

class _Allocation extends DepotAllocationState {
  List<DepotHolding>? refreshed;

  @override
  Future<void> refresh(Iterable<DepotHolding> holdings) async {
    refreshed = holdings.toList();
  }
}

void main() {
  testWidgets(
    'sync button refreshes the newly synced holdings and shows busy state',
    (tester) async {
      final portfolio = _Portfolio();
      final allocation = _Allocation();
      addTearDown(portfolio.dispose);
      addTearDown(allocation.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DepotPortfolioState>.value(value: portfolio),
            ChangeNotifierProvider<DepotAllocationState>.value(
              value: allocation,
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DepotAllocationRefreshButton()),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      expect(portfolio.calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      portfolio.done.complete();
      await tester.pump();
      expect(allocation.refreshed?.single.id, 'new');
    },
  );
}
