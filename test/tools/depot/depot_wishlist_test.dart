import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
import 'package:tool_lab/tools/depot/parqet/parqet_asset_lookup.dart';
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

  test('ISIN lookup only accepts symbols from the matching asset', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'api.parqet.com');
      expect(request.url.path, startsWith('/v1/assets/'));
      return http.Response('''
        {"asset":{"security":{"isin":"US0378331005","symbols":[
          {"symbol":"AAPL"},{"symbol":"APC.DE"},{"symbol":null}
        ]}}}
      ''', 200);
    });
    expect(
      await ParqetAssetLookup(client: client).symbolsForIsin('US0378331005'),
      {'AAPL', 'APC.DE'},
    );
    expect(
      await ParqetAssetLookup(client: client).symbolsForIsin('US0378331006'),
      isEmpty,
    );
    client.close();
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

  test(
    'currency preference persists and ISIN links to an existing item',
    () async {
      await store.deleteWishlistItem('AAPL');
      await store.deleteWishlistLogo('AAPL');
      await store.setWishlistEuroDisplay(true);
      final state = DepotWishlistState(
        quoteLoader: (_) async => const DepotWishlistQuote(
          price: 100,
          previousClose: 90,
          currency: 'USD',
          exchange: 'NASDAQ',
          points: [],
        ),
        fxLoader: (_, _) async => 0.9,
        logoLoader: (_) async => throw const FormatException('offline'),
      );
      addTearDown(state.dispose);
      await state.ensureLoaded();
      const result = DepotWishlistSearchResult(
        symbol: 'AAPL',
        name: 'Apple',
        quoteType: 'EQUITY',
        exchange: 'NASDAQ',
      );
      expect(await state.add(result), isTrue);
      final addedAt = state.items.single.addedAt;
      const linked = DepotWishlistSearchResult(
        symbol: 'AAPL',
        name: 'Apple',
        quoteType: 'EQUITY',
        exchange: 'NASDAQ',
        isin: 'US0378331005',
      );
      expect(state.canLinkIsin(linked), isTrue);
      expect(await state.add(linked), isTrue);
      expect(state.items.single.isin, 'US0378331005');
      expect(state.items.single.addedAt, addedAt);
      expect((await store.wishlistItems()).single.isin, 'US0378331005');
      await state.setShowEuro(false);
      expect(state.displayEuroRate('USD'), isNull);
      expect(await store.wishlistEuroDisplay(), isFalse);
      await state.setShowEuro(true);
      expect(await store.wishlistEuroDisplay(), isTrue);
      await state.remove('AAPL');
    },
  );

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
    'sorts daily changes descending and keeps unavailable values last',
    () async {
      final changes = <String, double?>{
        'GAIN': 5,
        'LOSS': -2,
        'FLAT': 0,
        'TIE': 5,
        'UNKNOWN': null,
        'INVALID': double.nan,
      };
      for (final symbol in changes.keys) {
        await store.deleteWishlistItem(symbol);
      }
      final state = DepotWishlistState(
        quoteLoader: (symbol) async => DepotWishlistQuote(
          price: 100,
          previousClose: changes[symbol] == null ? 0 : 100,
          currency: 'EUR',
          exchange: '',
          points: const [],
          quotedDayChangePercent: changes[symbol],
        ),
        logoLoader: (_) async => throw const FormatException('offline'),
      );
      addTearDown(state.dispose);
      await state.ensureLoaded();
      for (final symbol in changes.keys) {
        expect(
          await state.add(
            DepotWishlistSearchResult(
              symbol: symbol,
              name: symbol,
              quoteType: 'EQUITY',
              exchange: '',
            ),
          ),
          isTrue,
        );
      }
      expect(state.itemsByDayChange.map((item) => item.symbol), [
        'TIE',
        'GAIN',
        'FLAT',
        'LOSS',
        'INVALID',
        'UNKNOWN',
      ]);
      changes['LOSS'] = 7;
      changes['GAIN'] = -5;
      await state.refresh();
      expect(state.itemsByDayChange.map((item) => item.symbol), [
        'LOSS',
        'TIE',
        'FLAT',
        'GAIN',
        'INVALID',
        'UNKNOWN',
      ]);
      for (final symbol in changes.keys) {
        await state.remove(symbol);
      }
    },
  );

  test('entries with no quote sort after losses', () async {
    for (final (symbol, date) in [
      ('NOQUOTE', DateTime(2026, 1, 2)),
      ('LOSS', DateTime(2026, 1, 1)),
    ]) {
      await store.saveWishlistItem(
        DepotWishlistItem(
          symbol: symbol,
          name: symbol,
          quoteType: 'EQUITY',
          exchange: '',
          currency: 'EUR',
          addedAt: date,
        ),
      );
    }
    final refreshed = Completer<void>();
    final state = DepotWishlistState(
      quoteLoader: (symbol) async {
        if (symbol == 'NOQUOTE') throw const FormatException('offline');
        return const DepotWishlistQuote(
          price: 90,
          previousClose: 100,
          currency: 'EUR',
          exchange: '',
          points: [],
        );
      },
      logoLoader: (_) async => throw const FormatException('offline'),
    );
    addTearDown(state.dispose);
    state.addListener(() {
      if (state.isLoaded && !state.isRefreshing && state.failed.isNotEmpty) {
        if (!refreshed.isCompleted) refreshed.complete();
      }
    });
    await state.ensureLoaded();
    await refreshed.future.timeout(const Duration(seconds: 5));
    expect(state.failed, contains('NOQUOTE'));
    expect(state.quoteFor('NOQUOTE'), isNull);
    expect(state.itemsByDayChange.map((item) => item.symbol), [
      'LOSS',
      'NOQUOTE',
    ]);
    await state.remove('NOQUOTE');
    await state.remove('LOSS');
  });

  test(
    'refresh preserves quotes added during a request and on failure',
    () async {
      await store.deleteWishlistItem('AAPL');
      await store.deleteWishlistItem('MSFT');
      final pending = Completer<DepotWishlistQuote>();
      var appleCalls = 0;
      final state = DepotWishlistState(
        logoLoader: (_) async => throw const FormatException('No logo'),
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

  test('converts current quotes to EUR and caches wishlist logos', () async {
    await store.deleteWishlistItem('EURTEST');
    await store.deleteWishlistLogo('EURTEST');
    final rateGate = Completer<double>();
    final ready = Completer<void>();
    var rateCalls = 0;
    var logoCalls = 0;
    final state = DepotWishlistState(
      quoteLoader: (_) async => const DepotWishlistQuote(
        price: 100,
        previousClose: 90,
        currency: 'USD',
        exchange: 'NASDAQ',
        points: [],
      ),
      fxLoader: (from, to) {
        expect((from, to), ('USD', 'EUR'));
        rateCalls++;
        return rateGate.future;
      },
      logoLoader: (_) async {
        logoCalls++;
        return Uint8List.fromList([1, 2, 3]);
      },
    );
    addTearDown(state.dispose);
    state.addListener(() {
      if (!ready.isCompleted &&
          state.euroRate('USD') != null &&
          state.logoFor('EURTEST') != null) {
        ready.complete();
      }
    });
    await state.ensureLoaded();
    expect(
      await state.add(
        const DepotWishlistSearchResult(
          symbol: 'EURTEST',
          name: 'Test',
          quoteType: 'EQUITY',
          exchange: 'NASDAQ',
        ),
      ),
      isTrue,
    );
    final refreshing = state.refresh();
    await Future<void>.delayed(Duration.zero);
    rateGate.complete(0.9);
    await refreshing;
    await ready.future.timeout(const Duration(seconds: 5));
    expect(state.euroRate('USD'), 0.9);
    expect(state.quoteFor('EURTEST')!.price * state.euroRate('USD')!, 90);
    expect(state.euroRate('EUR'), 1);
    expect(rateCalls, 1);
    expect(logoCalls, 1);
    await store.clear();
    expect((await store.wishlistLogos()).single.key, 'EURTEST');
    expect(
      (await store.dumpTables()).any((table) => table.name == 'wishlist_logos'),
      isTrue,
    );
    final restored = DepotWishlistState(
      quoteLoader: (_) async => const DepotWishlistQuote(
        price: 100,
        previousClose: 90,
        currency: 'EUR',
        exchange: 'NASDAQ',
        points: [],
      ),
      logoLoader: (_) async => throw StateError('Cached logo was not used'),
    );
    await restored.ensureLoaded();
    expect(restored.logoFor('EURTEST'), [1, 2, 3]);
    restored.dispose();
    expect(await state.remove('EURTEST'), isTrue);
    expect(await store.wishlistLogos(), isEmpty);
  });

  test('failed EUR rates leave the original quote available', () async {
    await store.deleteWishlistItem('FXFAIL');
    final state = DepotWishlistState(
      quoteLoader: (_) async => const DepotWishlistQuote(
        price: 100,
        previousClose: 90,
        currency: 'USD',
        exchange: 'NASDAQ',
        points: [],
      ),
      fxLoader: (_, _) async => throw const FormatException('offline'),
      logoLoader: (_) async => throw const FormatException('offline'),
    );
    addTearDown(state.dispose);
    await state.ensureLoaded();
    expect(
      await state.add(
        const DepotWishlistSearchResult(
          symbol: 'FXFAIL',
          name: 'Test',
          quoteType: 'EQUITY',
          exchange: 'NASDAQ',
        ),
      ),
      isTrue,
    );
    await state.refresh();
    expect(state.euroRate('USD'), isNull);
    expect(state.quoteFor('FXFAIL')!.price, 100);
    expect(state.quoteFor('FXFAIL')!.currency, 'USD');
    await state.remove('FXFAIL');
  });

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

  testWidgets('row shows converted euros or the original currency', (
    tester,
  ) async {
    final logos = DepotLogoState();
    await tester.runAsync(logos.ensureLoaded);
    addTearDown(logos.dispose);
    const usdQuote = DepotWishlistQuote(
      price: 100,
      previousClose: 90,
      currency: 'USD',
      exchange: 'NASDAQ',
      points: [],
    );
    Future<void> show(double? rate) => tester.pumpWidget(
      app(
        ChangeNotifierProvider.value(
          value: logos,
          child: DepotWishlistRow(
            item: _item(),
            quote: usdQuote,
            failed: false,
            euroRate: rate,
            onTap: () {},
          ),
        ),
      ),
    );
    await show(0.9);
    expect(
      find.text('≈ ${DepotFormat('de', 'EUR').money(90)}'),
      findsOneWidget,
    );
    await show(null);
    expect(find.text(DepotFormat('de', 'USD').money(100)), findsOneWidget);
  });

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
          child: const SelectionArea(child: DepotWishlistView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Deine Wunschliste ist leer'), findsOneWidget);
  });

  testWidgets('wishlist reorders when daily changes refresh', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final changes = {'UP': 3.0, 'DOWN': -2.0, 'FLAT': 0.0};
    final state = DepotWishlistState(
      quoteLoader: (symbol) async => DepotWishlistQuote(
        price: 100,
        previousClose: 100,
        currency: 'EUR',
        exchange: '',
        points: const [],
        quotedDayChangePercent: changes[symbol],
      ),
      logoLoader: (_) async => throw const FormatException('offline'),
    );
    late final DepotLogoState logos;
    addTearDown(state.dispose);
    await tester.runAsync(() async {
      logos = DepotLogoState();
      for (final symbol in changes.keys) {
        await store.deleteWishlistItem(symbol);
      }
      await logos.ensureLoaded();
      await state.ensureLoaded();
      for (final symbol in changes.keys) {
        await state.add(
          DepotWishlistSearchResult(
            symbol: symbol,
            name: symbol,
            quoteType: 'EQUITY',
            exchange: '',
          ),
        );
      }
    });
    addTearDown(logos.dispose);
    await tester.pumpWidget(
      app(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: state),
            ChangeNotifierProvider.value(value: logos),
          ],
          child: const DepotWishlistView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    List<String> visibleSymbols() => tester
        .widgetList<DepotWishlistRow>(find.byType(DepotWishlistRow))
        .map((row) => row.item.symbol)
        .toList();
    expect(visibleSymbols(), ['UP', 'FLAT', 'DOWN']);
    changes['DOWN'] = 8;
    await tester.runAsync(state.refresh);
    await tester.pumpAndSettle();
    expect(visibleSymbols(), ['DOWN', 'UP', 'FLAT']);
    await tester.runAsync(() async {
      for (final symbol in changes.keys) {
        await state.remove(symbol);
      }
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('currency switch and ISIN are visible on the wishlist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = DepotWishlistState(
      quoteLoader: (_) async => const DepotWishlistQuote(
        price: 100,
        previousClose: 90,
        currency: 'USD',
        exchange: 'NASDAQ',
        points: [],
      ),
      fxLoader: (_, _) async => 0.9,
      logoLoader: (_) async => throw const FormatException('offline'),
    );
    late final DepotLogoState logos;
    addTearDown(state.dispose);
    await tester.runAsync(() async {
      logos = DepotLogoState();
      await store.deleteWishlistItem('AAPL');
      await store.setWishlistEuroDisplay(true);
      await logos.ensureLoaded();
      await state.ensureLoaded();
      await state.add(
        const DepotWishlistSearchResult(
          symbol: 'AAPL',
          name: 'Apple',
          quoteType: 'EQUITY',
          exchange: 'NASDAQ',
          isin: 'US0378331005',
        ),
      );
      await state.refresh();
    });
    addTearDown(logos.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: state),
          ChangeNotifierProvider.value(value: logos),
        ],
        child: app(const SelectionArea(child: DepotWishlistView())),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('≈ ${DepotFormat('de', 'EUR').money(90)}'),
      findsOneWidget,
    );
    expect(find.textContaining('US0378331005'), findsOneWidget);
    await tester.tap(find.text('Apple'));
    await tester.pumpAndSettle();
    final isin = find.text('US0378331005');
    expect(isin, findsOneWidget);
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
    final bounds = tester.getRect(isin);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: bounds.centerLeft);
    await mouse.down(bounds.centerLeft + const Offset(1, 0));
    await mouse.moveTo(bounds.centerRight - const Offset(1, 0));
    await mouse.up();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(copied, 'US0378331005');
    await mouse.removePointer();
    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    await tester.runAsync(() => state.setShowEuro(false));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(find.text(DepotFormat('de', 'USD').money(100)), findsOneWidget);
    await tester.runAsync(() async {
      expect(await store.wishlistEuroDisplay(), isFalse);
      await state.setShowEuro(true);
      await state.remove('AAPL');
    });
    expect(tester.takeException(), isNull);
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
