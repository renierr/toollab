import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/depot/depot_logo_state.dart';
import 'package:tool_lab/tools/depot/depot_format.dart';
import 'package:tool_lab/tools/depot/depot_data_export.dart';
import 'package:tool_lab/tools/depot/depot_store.dart';
import 'package:tool_lab/tools/depot/depot_wishlist_state.dart';
import 'package:tool_lab/tools/depot/dividends/yahoo_finance_api.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/models/depot_wishlist.dart';
import 'package:tool_lab/tools/depot/widgets/depot_wishlist_add_dialog.dart';
import 'package:tool_lab/tools/depot/widgets/depot_wishlist_chart.dart';
import 'package:tool_lab/tools/depot/widgets/depot_wishlist_row.dart';
import 'package:tool_lab/tools/depot/widgets/depot_wishlist_view.dart';

DepotWishlistItem _item() => DepotWishlistItem(
  symbol: 'AAPL',
  name: 'Apple Inc.',
  quoteType: 'EQUITY',
  exchange: 'NASDAQ',
  currency: 'USD',
  addedPrice: 100.5,
  addedAt: DateTime(2026, 1, 1),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = DepotStore.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });
  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  test('items survive a Parqet clear and are part of the export', () async {
    await store.clear();
    await store.deleteWishlistItem('AAPL');
    await store.saveWishlistItem(_item());

    final loaded = await store.wishlistItems();
    expect(loaded.single.symbol, 'AAPL');
    expect(loaded.single.addedPrice, 100.5);
    expect(loaded.single.addedAt, DateTime(2026, 1, 1));

    await store.clear();
    expect((await store.wishlistItems()).single.symbol, 'AAPL');

    final dump = (await store.dumpTables()).firstWhere(
      (table) => table.name == 'wishlist_items',
    );
    expect(
      dump.columns,
      containsAll(['symbol', 'name', 'quote_type', 'currency', 'added_price']),
    );
    expect(dump.rows, hasLength(1));
    expect(
      DepotDataExport.csv(dump),
      contains(_item().addedAt.toUtc().toIso8601String()),
    );

    await store.deleteWishlistItem('AAPL');
    expect(await store.wishlistItems(), isEmpty);
  });

  test('change windows follow the closes and prefer Yahoo day change', () {
    DepotWishlistPoint point(DateTime date, double close) =>
        DepotWishlistPoint(date: date, close: close);
    final quote = DepotWishlistQuote(
      price: 120,
      previousClose: 118,
      currency: 'EUR',
      exchange: 'XETRA',
      quotedDayChangePercent: 1.5,
      points: [
        point(DateTime(2025, 1, 1), 50),
        point(DateTime(2025, 6, 1), 100),
        point(DateTime(2025, 12, 15), 110),
        point(DateTime(2026, 1, 1), 120),
      ],
    );

    expect(quote.dayChangePercent, 1.5);
    expect(quote.changeSince(const Duration(days: 30)), closeTo(9.09, 0.01));
    expect(quote.changeSince(const Duration(days: 365)), 140);
    expect(quote.changeFrom(60), 100);
    expect(quote.pointsSince(const Duration(days: 30)), hasLength(2));
  });

  test('wishlist kinds map from Yahoo quote types', () {
    expect(wishlistKind('EQUITY', 'Apple Inc.'), DepotHoldingKind.stock);
    expect(
      wishlistKind('ETF', 'Vanguard FTSE All-World'),
      DepotHoldingKind.etf,
    );
    expect(wishlistKind('MUTUALFUND', 'Global Fund'), DepotHoldingKind.fund);
    expect(
      wishlistKind('CRYPTOCURRENCY', 'Bitcoin USD'),
      DepotHoldingKind.crypto,
    );
    expect(wishlistKind('FUTURE', 'Apple Futures'), DepotHoldingKind.other);
  });

  test('pence quotes normalize prices but not percentages', () {
    final quote = YahooFinanceApi.parseWishlistQuote({
      'chart': {
        'result': [
          {
            'meta': {
              'currency': 'GBp',
              'regularMarketPrice': 1250,
              'regularMarketChangePercent': 2.5,
            },
            'timestamp': [1000, 2000],
            'indicators': {
              'quote': [
                {
                  'close': [1200, 1250],
                },
              ],
            },
          },
        ],
      },
    }, 'TEST.L');
    expect(quote.currency, 'GBP');
    expect(quote.price, 12.5);
    expect(quote.points.first.close, 12);
    expect(quote.dayChangePercent, 2.5);
  });

  Widget app(Widget child) => MaterialApp(
    locale: const Locale('de'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  DepotWishlistQuote quote() => DepotWishlistQuote(
    price: 120,
    previousClose: 118,
    currency: 'EUR',
    exchange: 'XETRA',
    dayHigh: 122,
    dayLow: 117,
    yearHigh: 130,
    yearLow: 80,
    quotedDayChangePercent: 1.5,
    points: [
      for (var i = 0; i < 240; i++)
        DepotWishlistPoint(
          date: DateTime(2025, 1, 1).add(Duration(days: i)),
          close: 80 + i * 0.2,
        ),
    ],
  );

  test(
    'refresh preserves quotes added during a request and on failure',
    () async {
      await store.deleteWishlistItem('AAPL');
      await store.deleteWishlistItem('MSFT');
      final pending = Completer<DepotWishlistQuote>();
      var appleCalls = 0;
      final state = DepotWishlistState(
        quoteLoader: (symbol) async {
          if (symbol == 'AAPL' && ++appleCalls == 2) return pending.future;
          return quote();
        },
      );
      addTearDown(state.dispose);
      await state.ensureLoaded();
      const apple = DepotWishlistSearchResult(
        symbol: 'AAPL',
        name: 'Apple',
        quoteType: 'EQUITY',
        exchange: 'NASDAQ',
      );
      const microsoft = DepotWishlistSearchResult(
        symbol: 'MSFT',
        name: 'Microsoft',
        quoteType: 'EQUITY',
        exchange: 'NASDAQ',
      );
      expect(await state.add(apple), isTrue);
      final refresh = state.refresh();
      expect(await state.add(microsoft), isTrue);
      pending.completeError(Exception('offline'));
      await refresh;
      expect(state.quoteFor('AAPL'), isNotNull);
      expect(state.failed, contains('AAPL'));
      expect(state.quoteFor('MSFT'), isNotNull);
      await state.remove('AAPL');
      await state.remove('MSFT');
    },
  );

  for (final width in [320.0, 800.0]) {
    testWidgets('wishlist row and chart fit ${width.toInt()} px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final logoState = DepotLogoState();
      await tester.runAsync(logoState.ensureLoaded);
      addTearDown(logoState.dispose);
      await tester.pumpWidget(
        app(
          ChangeNotifierProvider.value(
            value: logoState,
            child: Column(
              children: [
                DepotWishlistRow(
                  item: _item(),
                  quote: quote(),
                  failed: false,
                  onTap: () {},
                ),
                SizedBox(
                  width: width,
                  child: DepotWishlistChart(
                    points: quote().points,
                    format: DepotFormat('de', 'EUR'),
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty wishlist view fits a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = DepotWishlistState();
    await tester.runAsync(() async {
      await store.clear();
      await store.deleteWishlistItem('AAPL');
      await state.ensureLoaded();
    });
    addTearDown(state.dispose);
    await tester.pumpWidget(
      app(
        ChangeNotifierProvider.value(
          value: state,
          child: const DepotWishlistView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Deine Wunschliste ist leer'), findsOneWidget);
  });

  testWidgets('search dialog fits a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = DepotWishlistState();
    addTearDown(state.dispose);
    await tester.runAsync(state.ensureLoaded);
    await tester.pumpWidget(
      app(
        ChangeNotifierProvider.value(
          value: state,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const DepotWishlistAddDialog(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
