import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/depot/depot_allocation.dart';
import 'package:tool_lab/tools/depot/depot_allocation_state.dart';
import 'package:tool_lab/tools/depot/depot_region.dart';
import 'package:tool_lab/tools/depot/depot_store.dart';
import 'package:tool_lab/tools/depot/market_data/yahoo_finance_api.dart';
import 'package:tool_lab/tools/depot/models/depot_asset_profile.dart';
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

    test('maps fund countries to regions and normalizes shares', () {
      final fund = _holding('fund', value: 400);
      final other = _holding('other', value: 600);
      final profile = _profile(
        countryShares: const {'United States': 0.75, 'Germany': 0.25},
      );

      final regions = depotAllocationBreakdown(
        holdings: [fund, other],
        profileOf: (holding) => holding.id == 'fund' ? profile : null,
        dimension: DepotAllocationDimension.region,
      );

      expect(regions[DepotRegion.northAmerica.name], 300);
      expect(regions[DepotRegion.europe.name], 100);
      expect(regions[null], 600);
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
      final restored = DepotAssetProfile.fromJson(profile.toJson());
      expect(restored.country, isNull);
      expect(
        depotAllocationBreakdown(
          holdings: [_holding('TSM')],
          profileOf: (_) => restored,
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
                (symbol: 'AAPL', weight: 3),
                (symbol: 'SAP', weight: 1),
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
        );
        addTearDown(state.dispose);
        final etf = _holding('ETF', isin: 'IE00ETF', value: 1000);

        await state.ensureProfiles([etf]);

        final profile = state.profileOf(etf);
        expect(profile, isNotNull);
        expect(profile!.sectorShares, {'Technology': 1});
        expect(profile.countryShares['United States'], closeTo(0.75, 0.001));
        expect(profile.countryShares['Germany'], closeTo(0.25, 0.001));
        expect(calls, containsAll(['IE00ETF', 'AAPL', 'SAP']));

        final reopened = DepotAllocationState(
          profileLoader: (query, session) async {
            calls.add(query);
            return null;
          },
          sessionLoader: () async => null,
        );
        addTearDown(reopened.dispose);
        await reopened.ensureProfiles([etf]);

        expect(reopened.profileOf(etf)?.countryShares, profile.countryShares);
        expect(calls.where((query) => query == 'IE00ETF'), hasLength(1));
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
        );
        addTearDown(state.dispose);
        await state.ensureProfiles([holding]);
        await state.ensureProfiles([holding]);
        expect(calls, ['AAPL']);
        expect(state.profileOf(holding)?.sector, 'Technology');
      },
    );

    test('refresh waits for an active fetch and then reloads', () async {
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
      );
      addTearDown(state.dispose);
      final initial = state.ensureProfiles([holding]);
      await started.future;
      final refresh = state.refresh([holding]);
      release.complete();
      await initial;
      await refresh;
      expect(calls, ['AAPL', 'AAPL']);
    });
  });
}
