import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/depot/depot_allocation_state.dart';
import 'package:tool_lab/tools/depot/depot_portfolio_state.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/widgets/depot_allocation_refresh_button.dart';
import 'package:tool_lab/tools/depot/widgets/depot_allocation_tab_view.dart';

class _Portfolio extends DepotPortfolioState {
  int calls = 0;
  List<DepotHolding> current = [
    DepotHolding.fromJson('p', {
      'id': 'existing',
      'asset': {'type': 'security', 'name': 'Existing'},
      'position': {'currentValue': 100},
    }),
  ];

  @override
  bool get isLoaded => true;
  @override
  bool get isConnected => true;
  @override
  List<DepotHolding> get holdings => current;

  @override
  Future<void> sync({bool full = false}) async {
    calls++;
  }
}

class _Allocation extends DepotAllocationState {
  List<DepotHolding>? refreshed;
  final done = Completer<void>();
  bool busy = false;

  @override
  bool get isFetching => busy;

  @override
  Future<void> refresh(Iterable<DepotHolding> holdings) async {
    refreshed = holdings.toList();
    busy = true;
    notifyListeners();
    await done.future;
    busy = false;
    notifyListeners();
  }
}

class _CacheOnlyAllocation extends DepotAllocationState {
  int loads = 0;
  int fetches = 0;
  @override
  Future<void> ensureLoaded() async {
    loads++;
  }

  @override
  Future<void> ensureProfiles(
    Iterable<DepotHolding> holdings, {
    bool force = false,
  }) async {
    fetches++;
  }
}

void main() {
  testWidgets('sync button fetches allocation only and shows busy state', (
    tester,
  ) async {
    final portfolio = _Portfolio();
    final allocation = _Allocation();
    addTearDown(portfolio.dispose);
    addTearDown(allocation.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DepotPortfolioState>.value(value: portfolio),
          ChangeNotifierProvider<DepotAllocationState>.value(value: allocation),
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
    expect(portfolio.calls, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    allocation.done.complete();
    await tester.pump();
    expect(allocation.refreshed?.single.id, 'existing');
  });

  testWidgets('opening allocation only loads the cache', (tester) async {
    final portfolio = _Portfolio()..current = [];
    final allocation = _CacheOnlyAllocation();
    addTearDown(portfolio.dispose);
    addTearDown(allocation.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DepotPortfolioState>.value(value: portfolio),
          ChangeNotifierProvider<DepotAllocationState>.value(value: allocation),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DepotAllocationTabView()),
        ),
      ),
    );
    await tester.pump();
    expect(allocation.loads, greaterThan(0));
    expect(allocation.fetches, 0);
    expect(portfolio.calls, 0);
  });
}
