import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/settings_service.dart';
import 'package:tool_lab/tools/depot/depot_dividend_state.dart';
import 'package:tool_lab/tools/depot/depot_holding_trend_state.dart';
import 'package:tool_lab/tools/depot/depot_import_state.dart';
import 'package:tool_lab/tools/depot/depot_logo_state.dart';
import 'package:tool_lab/tools/depot/depot_page.dart';
import 'package:tool_lab/tools/depot/depot_portfolio_state.dart';
import 'package:tool_lab/tools/depot/depot_state.dart';
import 'package:tool_lab/tools/depot/depot_wishlist_state.dart';

import 'offline_test_support.dart';

class _Trends extends DepotHoldingTrendState {
  int reductions = 0;
  @override
  void reduceCache() => reductions++;
}

class _Wishlist extends DepotWishlistState {
  int reductions = 0;
  @override
  void reduceCache() => reductions++;
}

class _Dividends extends DepotDividendState {
  int reductions = 0;
  @override
  void reduceCache() => reductions++;
}

class _Logos extends DepotLogoState {
  int reductions = 0;
  @override
  Future<void> ensureLoaded() async {}
  @override
  void reduceCache() {
    reductions++;
    super.reduceCache();
  }
}

class _Portfolio extends DepotPortfolioState {
  @override
  Future<void> syncIfStale() async {}
}

void main() {
  blockDepotNetwork();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });
  tearDownAll(() async => DatabaseService.instance.close());
  testWidgets('leaving Depot reduces its transient caches', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final appState = await tester.runAsync(() async {
      final settings = await SettingsService.init();
      final state = AppState(settings);
      await state.reloadFromDatabase();
      return state;
    });
    final trends = _Trends();
    final wishlist = _Wishlist();
    final dividends = _Dividends();
    final logos = _Logos();
    final portfolio = _Portfolio();
    final imports = DepotImportState();
    final tabs = DepotState();
    final router = GoRouter(
      initialLocation: '/depot',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/depot', builder: (_, _) => const DepotPage()),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState!),
          ChangeNotifierProvider<DepotHoldingTrendState>.value(value: trends),
          ChangeNotifierProvider<DepotWishlistState>.value(value: wishlist),
          ChangeNotifierProvider<DepotDividendState>.value(value: dividends),
          ChangeNotifierProvider<DepotLogoState>.value(value: logos),
          ChangeNotifierProvider<DepotPortfolioState>.value(value: portfolio),
          ChangeNotifierProvider<DepotImportState>.value(value: imports),
          ChangeNotifierProvider<DepotState>.value(value: tabs),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (_, child) => Stack(
            children: [
              child!,
              Consumer<DepotLogoState>(builder: (_, _, _) => const SizedBox()),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(trends.reductions, 0);
    router.go('/');
    await tester.pumpAndSettle();
    expect(trends.reductions, 1);
    expect(wishlist.reductions, 1);
    expect(dividends.reductions, 1);
    expect(logos.reductions, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    trends.dispose();
    wishlist.dispose();
    dividends.dispose();
    logos.dispose();
    portfolio.dispose();
    imports.dispose();
    tabs.dispose();
    appState.dispose();
  });
}
