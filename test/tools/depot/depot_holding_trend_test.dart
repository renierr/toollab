import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/depot/depot_format.dart';
import 'package:tool_lab/tools/depot/depot_holding_trend_state.dart';
import 'package:tool_lab/tools/depot/depot_logo_state.dart';
import 'package:tool_lab/tools/depot/depot_market_search.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/models/depot_period.dart';
import 'package:tool_lab/tools/depot/models/depot_wishlist.dart';
import 'package:tool_lab/tools/depot/models/market_quote.dart';
import 'package:tool_lab/tools/depot/parqet/parqet_asset_lookup.dart';
import 'package:tool_lab/tools/depot/widgets/depot_holding_tile.dart';
import 'package:tool_lab/tools/depot/widgets/depot_holding_trend.dart';
import 'package:tool_lab/widgets/sparkline.dart';

import 'offline_test_support.dart';

DepotHolding holding(int index, {String? isin, String? exchange}) =>
    DepotHolding(
      id: '$index',
      portfolioId: 'p',
      name: 'Holding $index',
      assetType: DepotAssetType.security,
      isin: isin ?? 'US00000000${index.toString().padLeft(2, '0')}',
      quoteExchange: exchange,
      shares: 1,
      purchasePrice: 1,
      purchaseValue: 1,
      currentPrice: 2,
      currentValue: 2,
      isSold: false,
      unrealizedGain: 1,
      unrealizedReturn: 100,
      realizedGain: 0,
      dividends: 0,
      fees: 0,
      taxes: 0,
    );

DepotWishlistQuote quote() => DepotWishlistQuote(
  price: 2,
  previousClose: 1,
  currency: 'USD',
  exchange: '',
  points: [
    DepotWishlistPoint(
      date: DateTime.now().subtract(const Duration(hours: 2)),
      close: 1,
    ),
    DepotWishlistPoint(
      date: DateTime.now().subtract(const Duration(hours: 1)),
      close: 2,
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  blockDepotNetwork();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });
  tearDownAll(() => DatabaseService.instance.close());

  test(
    'limits concurrent requests, deduplicates and drops invisible queue entries',
    () async {
      final requests = <String>[];
      final gates = <String, Completer<List<String>>>{};
      var now = DateTime.now();
      final state = DepotHoldingTrendState(
        now: () => now,
        resolve: (holding) {
          final isin = holding.isin!;
          requests.add(isin);
          return (gates[isin] = Completer()).future;
        },
        quote: (_) async => quote(),
      );
      addTearDown(state.dispose);
      var fifthVisible = true;
      for (var i = 0; i < 6; i++) {
        state.ensure(holding(i), visible: () => i != 4 || fifthVisible);
      }
      state.ensure(holding(0), visible: () => true);
      expect(requests, hasLength(4));
      fifthVisible = false;
      final first = holding(0).isin!;
      gates[first]!.complete([first]);
      await Future<void>.delayed(Duration.zero);
      expect(requests, hasLength(5));
      expect(requests.last, holding(5).isin);
      expect(state.trendFor(holding(0))?.points.map((p) => p.close), [1, 2]);
      state.ensure(holding(0), visible: () => true);
      expect(requests, hasLength(5));
      now = now.add(const Duration(minutes: 16));
      state.ensure(holding(0), visible: () => true);
      expect(requests, hasLength(5));
      final second = holding(1).isin!;
      gates[second]!.complete([second]);
      await Future<void>.delayed(Duration.zero);
      expect(requests.last, first);
      for (final entry in gates.entries) {
        if (!entry.value.isCompleted) entry.value.complete([entry.key]);
      }
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('does not fetch unconfirmed listings', () async {
    var quotes = 0;
    final state = DepotHoldingTrendState(
      resolve: (_) async => [],
      quote: (_) async {
        quotes++;
        return quote();
      },
    );
    addTearDown(state.dispose);
    state.ensure(holding(0), visible: () => true);
    await Future<void>.delayed(Duration.zero);
    expect(quotes, 0);
    expect(state.trendFor(holding(0)), isNull);
  });

  test(
    'reduces cached points on exit without resetting the 15 minute throttle',
    () async {
      var now = DateTime.now();
      var requests = 0;
      final points = [
        for (var i = 0; i < 200; i++)
          DepotWishlistPoint(
            date: now.subtract(Duration(minutes: 200 - i)),
            close: i + 1.0,
          ),
      ];
      final state = DepotHoldingTrendState(
        now: () => now,
        resolve: (holding) async {
          requests++;
          return [holding.isin!];
        },
        quote: (_) async => DepotWishlistQuote(
          price: 200,
          previousClose: 100,
          currency: 'EUR',
          exchange: '',
          points: points,
        ),
      );
      addTearDown(state.dispose);
      state.ensure(holding(0), visible: () => true);
      await Future<void>.delayed(Duration.zero);
      expect(state.trendFor(holding(0))?.points, hasLength(200));
      state.reduceCache();
      final reduced = state.trendFor(holding(0))!.points;
      expect(reduced, hasLength(48));
      expect(reduced.first.close, points.first.close);
      expect(reduced.last.close, points.last.close);
      state.ensure(holding(0), visible: () => true);
      await Future<void>.delayed(Duration.zero);
      expect(requests, 1);
      now = now.add(const Duration(minutes: 16));
      state.ensure(holding(0), visible: () => true);
      await Future<void>.delayed(Duration.zero);
      expect(requests, 2);
    },
  );

  test(
    'closing discards an in-flight trend and allows a later visible retry',
    () async {
      final first = Completer<DepotWishlistQuote>();
      final next = Completer<DepotWishlistQuote>();
      var calls = 0;
      final state = DepotHoldingTrendState(
        resolve: (_) async => ['GOOGL'],
        quote: (_) => ++calls == 1 ? first.future : next.future,
      );
      addTearDown(state.dispose);
      state.ensure(holding(0), visible: () => true);
      await Future<void>.delayed(Duration.zero);
      state.reduceCache();
      state.ensure(holding(0), visible: () => true);
      first.complete(quote());
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
      expect(state.trendFor(holding(0)), isNull);
      next.complete(quote());
      await Future<void>.delayed(Duration.zero);
      expect(state.trendFor(holding(0))?.symbol, 'GOOGL');
    },
  );

  test('holding cache is bounded and expired entries are discarded', () async {
    var now = DateTime.now();
    final state = DepotHoldingTrendState(
      now: () => now,
      resolve: (holding) async => [holding.isin!],
      quote: (_) async => quote(),
    );
    addTearDown(state.dispose);
    for (var i = 0; i < 130; i++) {
      state.ensure(holding(i), visible: () => true);
    }
    await Future<void>.delayed(Duration.zero);
    expect(state.trendFor(holding(0)), isNull);
    expect(state.trendFor(holding(129)), isNotNull);
    now = now.add(const Duration(minutes: 16));
    state.reduceCache();
    expect(state.trendFor(holding(129)), isNull);
  });

  testWidgets('expired trends are released even when the tool is closed', (
    tester,
  ) async {
    final state = DepotHoldingTrendState(
      now: tester.binding.clock.now,
      resolve: (holding) async => [holding.isin!],
      quote: (_) async => DepotWishlistQuote(
        price: 2,
        previousClose: 1,
        currency: 'EUR',
        exchange: '',
        points: [
          DepotWishlistPoint(
            date: tester.binding.clock.now().subtract(const Duration(hours: 2)),
            close: 1,
          ),
          DepotWishlistPoint(
            date: tester.binding.clock.now().subtract(const Duration(hours: 1)),
            close: 2,
          ),
        ],
      ),
    );
    state.ensure(holding(0), visible: () => true);
    await tester.pump();
    expect(state.trendFor(holding(0)), isNotNull);
    state.reduceCache();
    await tester.pump(const Duration(minutes: 15));
    expect(state.trendFor(holding(0)), isNull);
    state.dispose();
  });

  test(
    'resolves Alphabet directly from Parqet and prefers its exchange',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/v1/assets/US02079K3059');
        return http.Response('''
        {"asset":{"security":{"isin":"US02079K3059","symbols":[
          {"exchange":"nasdaq","symbol":"GOOGL"},
          {"exchange":"xetra","symbol":"ABEA.DE"}
        ]}}}
      ''', 200);
      });
      addTearDown(client.close);
      final alphabet = holding(0, isin: 'US02079K3059', exchange: 'xetra');
      final symbols = await DepotMarketSearch.holdingSymbols(
        alphabet,
        assets: ParqetAssetLookup(client: client),
        searchListings: (_) =>
            throw StateError('Yahoo search must not be used'),
      );
      expect(symbols, ['ABEA.DE', 'GOOGL']);
    },
  );

  test('ISIN search falls back to the confirmed Alphabet ticker', () async {
    final client = MockClient(
      (_) async => http.Response('''
      {"asset":{"security":{"isin":"US02079K3059","symbols":[
        {"exchange":"nasdaq","symbol":"GOOGL"}
      ]}}}
    ''', 200),
    );
    addTearDown(client.close);
    final queries = <String>[];
    final results = await DepotMarketSearch.search(
      'US02079K3059',
      assets: ParqetAssetLookup(client: client),
      searchListings: (query) async {
        queries.add(query);
        if (query != 'GOOGL') return [];
        return [
          const MarketSearchResult(
            symbol: 'GOOGL',
            name: 'Alphabet',
            quoteType: 'EQUITY',
            exchange: 'NASDAQ',
          ),
          const MarketSearchResult(
            symbol: 'GOOG',
            name: 'Alphabet',
            quoteType: 'EQUITY',
            exchange: 'NASDAQ',
          ),
        ];
      },
    );
    expect(queries, ['US02079K3059', 'GOOGL']);
    expect(results.single.symbol, 'GOOGL');
    expect(results.single.isin, 'US02079K3059');
  });

  test('tries another confirmed listing when a chart is unavailable', () async {
    final requested = <String>[];
    final state = DepotHoldingTrendState(
      resolve: (_) async => ['ABEA.DE', 'GOOGL'],
      quote: (symbol) async {
        requested.add(symbol);
        if (symbol == 'ABEA.DE') throw const FormatException('unavailable');
        return quote();
      },
    );
    addTearDown(state.dispose);
    state.ensure(holding(0), visible: () => true);
    await Future<void>.delayed(Duration.zero);
    expect(requested, ['ABEA.DE', 'GOOGL']);
    expect(state.trendFor(holding(0))?.symbol, 'GOOGL');
  });

  test(
    'tries another confirmed listing when the first has too few prices',
    () async {
      final requested = <String>[];
      final state = DepotHoldingTrendState(
        resolve: (_) async => ['DPSTF', 'DHL.DE'],
        quote: (symbol) async {
          requested.add(symbol);
          if (symbol == 'DPSTF') {
            return DepotWishlistQuote(
              price: 65,
              previousClose: 64,
              currency: 'USD',
              exchange: '',
              points: [DepotWishlistPoint(date: DateTime.now(), close: 65)],
            );
          }
          return quote();
        },
      );
      addTearDown(state.dispose);
      state.ensure(holding(0, isin: 'DE0005552004'), visible: () => true);
      await Future<void>.delayed(Duration.zero);
      expect(requested, ['DPSTF', 'DHL.DE']);
      expect(
        state.trendFor(holding(0, isin: 'DE0005552004'))?.symbol,
        'DHL.DE',
      );
    },
  );

  test('stops after three listings without enough prices', () async {
    final requested = <String>[];
    final state = DepotHoldingTrendState(
      resolve: (_) async => ['ONE', 'TWO', 'THREE', 'FOUR'],
      quote: (symbol) async {
        requested.add(symbol);
        return const DepotWishlistQuote(
          price: 1,
          previousClose: 1,
          currency: 'EUR',
          exchange: '',
          points: [],
        );
      },
    );
    addTearDown(state.dispose);
    state.ensure(holding(0), visible: () => true);
    await Future<void>.delayed(Duration.zero);
    expect(requested, ['ONE', 'TWO', 'THREE']);
    expect(state.trendFor(holding(0)), isNull);
  });

  test('does not fetch a chart after its row leaves the viewport', () async {
    final gate = Completer<List<String>>();
    var visible = true;
    var chartCalls = 0;
    final state = DepotHoldingTrendState(
      resolve: (_) => gate.future,
      quote: (_) async {
        chartCalls++;
        return quote();
      },
    );
    addTearDown(state.dispose);
    state.ensure(holding(0), visible: () => visible);
    visible = false;
    gate.complete([holding(0).isin!]);
    await Future<void>.delayed(Duration.zero);
    expect(chartCalls, 0);
    visible = true;
    state.ensure(holding(0), visible: () => visible);
    await Future<void>.delayed(Duration.zero);
    expect(chartCalls, 1);
  });

  test(
    'duplicate holdings share a request while either row is visible',
    () async {
      final gate = Completer<List<String>>();
      var firstVisible = true;
      var chartCalls = 0;
      final state = DepotHoldingTrendState(
        resolve: (_) => gate.future,
        quote: (_) async {
          chartCalls++;
          return quote();
        },
      );
      addTearDown(state.dispose);
      state.ensure(holding(0), visible: () => firstVisible);
      state.ensure(holding(0), visible: () => true);
      firstVisible = false;
      gate.complete(['GOOGL']);
      await Future<void>.delayed(Duration.zero);
      expect(chartCalls, 1);
      expect(state.trendFor(holding(0))?.symbol, 'GOOGL');
    },
  );

  testWidgets('loads only rows in the viewport without blocking', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <String>[];
    final gate = Completer<DepotWishlistQuote>();
    final state = DepotHoldingTrendState(
      resolve: (holding) async {
        final isin = holding.isin!;
        requests.add(isin);
        return [isin];
      },
      quote: (_) => gate.future,
    );
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverFixedExtentList.builder(
                  itemExtent: 100,
                  itemCount: 20,
                  itemBuilder: (_, i) => Row(
                    children: [
                      Text('Item $i'),
                      DepotHoldingTrendView(holding: holding(i)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Item 0'), findsOneWidget);
    expect(requests, [holding(0).isin, holding(1).isin]);
    expect(find.byType(Sparkline), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();
    await tester.pump();
    expect(requests, contains(holding(3).isin));
    expect(requests, isNot(contains(holding(8).isin)));
    gate.complete(quote());
    await tester.pumpAndSettle();
    expect(find.byType(Sparkline), findsWidgets);
    expect(tester.takeException(), isNull);
    state.clear();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (width, scale) in [
    (320.0, 1.0),
    (320.0, 2.0),
    (800.0, 1.0),
    (800.0, 2.0),
  ]) {
    testWidgets('holding row fits at $width with text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var requests = 0;
      final trends = DepotHoldingTrendState(
        resolve: (holding) async {
          requests++;
          return [holding.isin!];
        },
        quote: (_) async => quote(),
      );
      late DepotLogoState logos;
      await tester.runAsync(() async {
        logos = DepotLogoState();
        await logos.ensureLoaded();
      });
      addTearDown(logos.dispose);
      addTearDown(trends.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: trends),
            ChangeNotifierProvider.value(value: logos),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: DepotHoldingTile(
                  holding: holding(0),
                  performance: null,
                  period: DepotPeriod.today,
                  format: DepotFormat('de', 'EUR'),
                  weight: 100,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, width == 320 ? 0 : 1);
      expect(
        find.byType(Sparkline),
        width == 320 ? findsNothing : findsOneWidget,
      );
      final tile = tester.getRect(find.byType(DepotHoldingTile));
      final values = find.text(DepotFormat('de', 'EUR').money(2));
      for (var index = 0; index < 2; index++) {
        final value = tester.getRect(values.at(index));
        expect(value.top, greaterThanOrEqualTo(tile.top));
        expect(value.bottom, lessThanOrEqualTo(tile.bottom));
      }
      expect(tester.takeException(), isNull);
      trends.clear();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
