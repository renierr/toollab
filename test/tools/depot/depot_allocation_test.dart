import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/depot/depot_allocation.dart';
import 'package:tool_lab/tools/depot/depot_allocation_state.dart';
import 'package:tool_lab/tools/depot/depot_region.dart';
import 'package:tool_lab/tools/depot/depot_store.dart';
import 'package:tool_lab/tools/depot/market_data/onvista_api.dart';
import 'package:tool_lab/tools/depot/market_data/yahoo_finance_api.dart';
import 'package:tool_lab/tools/depot/models/depot_asset_profile.dart';
import 'package:tool_lab/tools/depot/models/depot_fund_constituent.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';

DepotHolding _holding(String id, {double value = 100, String? isin}) =>
    DepotHolding.fromJson('p1', {
      'id': id,
      'asset': {'type': 'security', 'name': id, 'isin': isin, 'symbol': id},
      'position': {
        'shares': 1,
        'currentPrice': value,
        'currentValue': value,
        'isSold': false,
      },
    });

Future<OnvistaFundBreakdown?> _noFund(String isin) async => null;

Future<String?> _noCountry(String isin) async => null;

DepotAssetProfile _profile({
  String? sector,
  String? industry,
  String? country,
  Map<String, double> sectorShares = const {},
  Map<String, double> countryShares = const {},
}) => DepotAssetProfile(
  sector: sector,
  industry: industry,
  country: country,
  sectorShares: sectorShares,
  countryShares: countryShares,
  fetchedAt: DateTime(2026, 10, 1),
);

void main() {
  group('breakdown', () {
    test(
      'splits a fund by its sector weights and keeps unclassified value',
      () {
        final stock = _holding('stock', value: 600);
        final fund = _holding('fund', value: 400);
        final cash = _holding('cash', value: 500);
        final profiles = {
          'stock': _profile(sector: 'Technology'),
          'fund': _profile(
            sectorShares: const {'Technology': 0.5, 'Financial Services': 0.5},
          ),
        };

        final sectors = depotAllocationBreakdown(
          holdings: [stock, fund, cash],
          profileOf: (holding) => profiles[holding.id],
          dimension: DepotAllocationDimension.sector,
        );

        expect(sectors['Technology'], 800);
        expect(sectors['Financial Services'], 200);
        expect(sectors[null], 500);
        expect(sectors.keys.last, 'Financial Services');
      },
    );

    test('maps fund countries to regions without inflating partial shares', () {
      final fund = _holding('fund', value: 400);
      final other = _holding('other', value: 600);
      final profile = _profile(
        countryShares: const {'United States': 0.30, 'Germany': 0.10},
      );

      final regions = depotAllocationBreakdown(
        holdings: [fund, other],
        profileOf: (holding) => holding.id == 'fund' ? profile : null,
        dimension: DepotAllocationDimension.region,
      );

      expect(regions[DepotRegion.northAmerica.name], closeTo(120, 0.001));
      expect(regions[DepotRegion.europe.name], closeTo(40, 0.001));
      expect(regions[null], closeTo(840, 0.001));
    });

    test('leaves missing sector weight unclassified', () {
      final sectors = depotAllocationBreakdown(
        holdings: [_holding('fund', value: 1000)],
        profileOf: (_) =>
            _profile(sectorShares: const {'Technology': 0.2, 'Energy': 0.1}),
        dimension: DepotAllocationDimension.sector,
      );
      expect(sectors['Technology'], closeTo(200, 0.001));
      expect(sectors['Energy'], closeTo(100, 0.001));
      expect(sectors[null], closeTo(700, 0.001));
    });

    test('handles tiny rounding excess without exceeding portfolio value', () {
      final sectors = depotAllocationBreakdown(
        holdings: [_holding('fund', value: 1000)],
        profileOf: (_) =>
            _profile(sectorShares: const {'Technology': 0.6, 'Energy': 0.4001}),
        dimension: DepotAllocationDimension.sector,
      );
      expect(
        sectors.values.fold<double>(0, (a, b) => a + b),
        closeTo(1000, 0.0001),
      );
      expect(sectors[null], isNull);
    });

    test('ignores normalized fund shares from old cache versions', () {
      final profile = DepotAssetProfile.fromLegacyJson({
        'cacheVersion': 2,
        'sectorShares': {'Technology': 1.0},
        'countryShares': {'United States': 1.0},
        'fetchedAt': DateTime.now().millisecondsSinceEpoch,
      });
      expect(profile.sectorShares, isEmpty);
      expect(profile.countryShares, isEmpty);
    });

    test('sold positions do not take part', () {
      final sold = DepotHolding.fromJson('p1', {
        'id': 'sold',
        'asset': {'type': 'security', 'name': 'Sold'},
        'position': {
          'shares': 0,
          'currentPrice': 10,
          'currentValue': 10,
          'isSold': true,
        },
      });

      final industries = depotAllocationBreakdown(
        holdings: [sold],
        profileOf: (_) => _profile(industry: 'Software'),
        dimension: DepotAllocationDimension.industry,
      );

      expect(industries, isEmpty);
    });

    test('uses a profile region without inventing a country', () {
      final profile = DepotAssetProfile(
        region: 'asia',
        fetchedAt: DateTime.now(),
      );
      expect(profile.country, isNull);
      expect(
        depotAllocationBreakdown(
          holdings: [_holding('TSM')],
          profileOf: (_) => profile,
          dimension: DepotAllocationDimension.region,
        ),
        {'asia': 100},
      );
    });
  });

  group('region', () {
    test('maps known countries and falls back to other', () {
      expect(DepotRegion.of('United States'), DepotRegion.northAmerica);
      expect(DepotRegion.of('cayman islands'), DepotRegion.northAmerica);
      expect(DepotRegion.of('Germany'), DepotRegion.europe);
      expect(DepotRegion.of('Japan'), DepotRegion.asia);
      expect(DepotRegion.of('Atlantis'), DepotRegion.other);
      expect(DepotRegion.of(null), DepotRegion.other);
    });
  });

  group('allocation state', () {
    final store = DepotStore.instance;
    final calls = <String>[];

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
    });
    setUp(() async {
      calls.clear();
      await store.clear();
    });
    tearDownAll(() async {
      await DatabaseService.instance.close();
    });

    test('stores profiles, shares and constituents in tables', () async {
      final fetchedAt = DateTime(2026, 10, 30);
      await store.saveAssetProfileAttempts({'IE00ETF': fetchedAt});
      await store.saveAssetProfiles({
        'IE00ETF': DepotAssetProfile(
          kind: DepotHoldingKind.etf,
          sectorShares: const {'Technology': 0.4},
          countryShares: const {'USA': 0.7, 'Japan': 0.06},
          constituents: const [
            DepotFundConstituent(
              name: 'Nvidia',
              isin: 'US67066G1040',
              weight: 0.058,
            ),
            DepotFundConstituent(name: 'Apple', symbol: 'AAPL', weight: 0.054),
          ],
          fetchedAt: fetchedAt,
        ),
      });
      await store.saveAssetProfileAttempts({'FAILED': fetchedAt});

      final profiles = await store.assetProfiles();
      final etf = profiles['IE00ETF']!;
      expect(profiles.keys, ['IE00ETF']);
      expect(etf.kind, DepotHoldingKind.etf);
      expect(etf.sectorShares, {'Technology': 0.4});
      expect(etf.countryShares, {'USA': 0.7, 'Japan': 0.06});
      expect(etf.constituents.map((c) => c.name), ['Nvidia', 'Apple']);
      expect(etf.constituents.last.symbol, 'AAPL');
      expect(etf.fetchedAt, fetchedAt);
      expect(await store.assetProfileAttempts(), {
        'IE00ETF': fetchedAt,
        'FAILED': fetchedAt,
      });
      final tables = {
        for (final table in await store.dumpTables()) table.name: table,
      };
      expect(tables['asset_profiles']!.rows, hasLength(2));
      expect(tables['asset_shares']!.rows, hasLength(3));
      expect(tables['fund_constituents']!.rows, hasLength(2));
    });

    test(
      'fetches missing profiles, derives fund regions, caches all',
      () async {
        Future<YahooAssetProfile?> loader(
          String query,
          YahooSession? session,
        ) async {
          calls.add(query);
          return switch (query) {
            'IE00ETF' => (
              profile: _profile(sectorShares: const {'Technology': 1}),
              topHoldings: <({String symbol, double weight})>[
                (symbol: 'AAPL', weight: 0.3),
                (symbol: 'SAP', weight: 0.1),
                (symbol: 'MISSING', weight: 0.2),
              ],
            ),
            'AAPL' => (
              profile: _profile(country: 'United States'),
              topHoldings: const <({String symbol, double weight})>[],
            ),
            'SAP' => (
              profile: _profile(country: 'Germany'),
              topHoldings: const <({String symbol, double weight})>[],
            ),
            _ => null,
          };
        }

        final state = DepotAllocationState(
          profileLoader: loader,
          sessionLoader: () async => null,
          fundLoader: _noFund,
          stockCountryLoader: _noCountry,
        );
        addTearDown(state.dispose);
        final etf = _holding('ETF', isin: 'IE00ETF', value: 1000);

        await state.ensureProfiles([etf]);

        final profile = state.profileOf(etf);
        expect(profile, isNotNull);
        expect(profile!.sectorShares, {'Technology': 1});
        expect(profile.countryShares['United States'], closeTo(0.3, 0.001));
        expect(profile.countryShares['Germany'], closeTo(0.1, 0.001));
        expect(calls, containsAll(['IE00ETF', 'AAPL', 'SAP']));
        final breakdown = depotAllocationBreakdown(
          holdings: [etf],
          profileOf: state.profileOf,
          dimension: DepotAllocationDimension.region,
        );
        expect(breakdown[null], closeTo(600, 0.001));

        final reopened = DepotAllocationState(
          profileLoader: (query, session) async {
            calls.add(query);
            return null;
          },
          sessionLoader: () async => null,
          fundLoader: _noFund,
          stockCountryLoader: _noCountry,
        );
        addTearDown(reopened.dispose);
        await reopened.ensureProfiles([etf]);

        expect(reopened.profileOf(etf)?.countryShares, profile.countryShares);
        expect(calls.where((query) => query == 'IE00ETF'), hasLength(1));
      },
    );

    test(
      'fills missing stock details from confirmed alternative listings',
      () async {
        final stock = _holding('stock', isin: 'DE0007164600');
        final state = DepotAllocationState(
          profileLoader: (query, session) async {
            calls.add(query);
            return switch (query) {
              'DE0007164600' => (
                profile: _profile(sector: 'Technology'),
                topHoldings: const <({String symbol, double weight})>[],
              ),
              'SAP' => (
                profile: _profile(industry: 'Software', country: 'Germany'),
                topHoldings: const <({String symbol, double weight})>[],
              ),
              _ => null,
            };
          },
          confirmedSymbolsLoader: (_) async => ['SAP.DE', 'SAP'],
          sessionLoader: () async => null,
          fundLoader: _noFund,
          stockCountryLoader: _noCountry,
        );
        addTearDown(state.dispose);
        await state.ensureProfiles([stock]);
        expect(calls, ['DE0007164600', 'SAP']);
        expect(state.profileOf(stock)?.sector, 'Technology');
        expect(state.profileOf(stock)?.industry, 'Software');
        expect(state.profileOf(stock)?.country, 'Germany');
      },
    );

    test(
      'never searches unconfirmed names when listings are unavailable',
      () async {
        final stock = _holding('stock', isin: 'DE0007164600');
        final state = DepotAllocationState(
          profileLoader: (query, session) async {
            calls.add(query);
            return null;
          },
          confirmedSymbolsLoader: (_) async => [],
          sessionLoader: () async => null,
          fundLoader: _noFund,
          stockCountryLoader: _noCountry,
        );
        addTearDown(state.dispose);
        await state.ensureProfiles([stock]);
        expect(calls, ['DE0007164600']);
        expect(state.profileOf(stock), isNull);
      },
    );

    test(
      'retries old partial profiles once without discarding them on failure',
      () async {
        final holding = _holding('AAPL');
        await store.saveAssetProfiles({
          'AAPL': DepotAssetProfile(
            sector: 'Technology',
            cacheVersion: 1,
            fetchedAt: DateTime.now(),
          ),
        });
        final state = DepotAllocationState(
          profileLoader: (query, session) async {
            calls.add(query);
            return null;
          },
          sessionLoader: () async => null,
          fundLoader: _noFund,
          stockCountryLoader: _noCountry,
        );
        addTearDown(state.dispose);
        await state.ensureProfiles([holding]);
        await state.ensureProfiles([holding]);
        expect(calls, ['AAPL']);
        expect(state.profileOf(holding)?.sector, 'Technology');
      },
    );

    test(
      'refreshes old normalized fund caches even when recently fetched',
      () async {
        final etf = _holding('ETF', isin: 'IE00ETF', value: 1000);
        await store.saveAssetProfiles({
          'IE00ETF': DepotAssetProfile(
            cacheVersion: 2,
            sectorShares: const {'Technology': 1},
            countryShares: const {'United States': 1},
            fetchedAt: DateTime.now(),
          ),
        });
        final state = DepotAllocationState(
          profileLoader: (query, session) async {
            calls.add(query);
            return (
              profile: DepotAssetProfile(
                sectorShares: const {'Technology': 0.4},
                fetchedAt: DateTime.now(),
              ),
              topHoldings: const <({String symbol, double weight})>[],
            );
          },
          sessionLoader: () async => null,
          fundLoader: _noFund,
          stockCountryLoader: _noCountry,
        );
        addTearDown(state.dispose);
        await state.ensureProfiles([etf]);
        expect(calls, ['IE00ETF']);
        expect(state.profileOf(etf)?.sectorShares, {'Technology': 0.4});
        expect(state.profileOf(etf)?.countryShares, isEmpty);
      },
    );

    test('refresh waits for an active fetch without repeating it', () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final holding = _holding('AAPL');
      final state = DepotAllocationState(
        profileLoader: (query, session) async {
          calls.add(query);
          if (calls.length == 1) {
            started.complete();
            await release.future;
          }
          return (
            profile: _profile(sector: 'Technology'),
            topHoldings: const <({String symbol, double weight})>[],
          );
        },
        sessionLoader: () async => null,
        fundLoader: _noFund,
        stockCountryLoader: _noCountry,
      );
      addTearDown(state.dispose);
      final initial = state.ensureProfiles([holding]);
      await started.future;
      final refresh = state.refresh([holding]);
      release.complete();
      await initial;
      await refresh;
      expect(calls, ['AAPL']);
    });

    test(
      'complete cached profiles never expire or fetch automatically',
      () async {
        final now = DateTime(2026, 10, 29);
        final holding = _holding('AAPL');
        await store.saveAssetProfiles({
          'AAPL': DepotAssetProfile(
            sector: 'Technology',
            industry: 'Electronics',
            country: 'United States',
            fetchedAt: now.subtract(const Duration(days: 365)),
          ),
        });
        final state = DepotAllocationState(
          clock: () => now,
          profileLoader: (query, session) async {
            calls.add(query);
            return null;
          },
          sessionLoader: () async => null,
          fundLoader: _noFund,
          stockCountryLoader: _noCountry,
        );
        addTearDown(state.dispose);
        await state.ensureLoaded();
        expect(calls, isEmpty);
        expect(state.profileOf(holding)?.sector, 'Technology');
        await state.refresh([holding]);
        expect(calls, isEmpty);
      },
    );

    test('failed lookups retry after one day across restarts', () async {
      var now = DateTime(2026, 10, 29);
      final holding = _holding('AAPL');
      DepotAllocationState makeState() => DepotAllocationState(
        clock: () => now,
        profileLoader: (query, session) async {
          calls.add(query);
          return null;
        },
        confirmedSymbolsLoader: (_) async => [],
        sessionLoader: () async => null,
        fundLoader: _noFund,
        stockCountryLoader: _noCountry,
      );
      final first = makeState();
      await first.refresh([holding]);
      await first.refresh([holding]);
      expect(calls, ['AAPL']);
      first.dispose();
      final reopened = makeState();
      addTearDown(reopened.dispose);
      now = now.add(const Duration(hours: 23));
      await reopened.refresh([holding]);
      expect(calls, ['AAPL']);
      now = now.add(const Duration(hours: 2));
      await reopened.refresh([holding]);
      expect(calls, ['AAPL', 'AAPL']);
    });

    test('retries missing fields without replacing known values', () async {
      final now = DateTime(2026, 10, 29);
      final holding = _holding('AAPL');
      await store.saveAssetProfiles({
        'AAPL': DepotAssetProfile(
          sector: 'Technology',
          fetchedAt: now.subtract(const Duration(days: 2)),
        ),
      });
      final state = DepotAllocationState(
        clock: () => now,
        profileLoader: (query, session) async => (
          profile: DepotAssetProfile(
            sector: 'Different',
            industry: 'Electronics',
            country: 'United States',
            fetchedAt: now,
          ),
          topHoldings: const <({String symbol, double weight})>[],
        ),
        sessionLoader: () async => null,
        fundLoader: _noFund,
        stockCountryLoader: _noCountry,
      );
      addTearDown(state.dispose);
      await state.refresh([holding]);
      expect(state.profileOf(holding)?.sector, 'Technology');
      expect(state.profileOf(holding)?.industry, 'Electronics');
      expect(state.profileOf(holding)?.country, 'United States');
    });
  });
}
