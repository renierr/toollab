import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/depot/config.dart';
import 'package:tool_lab/tools/depot/depot_parqet_sync.dart';
import 'package:tool_lab/tools/depot/depot_portfolio_state.dart';
import 'package:tool_lab/tools/depot/depot_store.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/models/depot_period.dart';
import 'package:tool_lab/tools/depot/models/depot_portfolio.dart';
import 'package:tool_lab/tools/depot/models/depot_summary.dart';
import 'package:tool_lab/tools/depot/models/depot_transaction.dart';
import 'package:tool_lab/tools/depot/parqet/parqet_api.dart';
import 'package:tool_lab/tools/depot/parqet/parqet_auth.dart';
import 'package:tool_lab/tools/depot/parqet/parqet_exception.dart';

const _portfolio = DepotPortfolio(id: 'p1', name: 'One', currency: 'EUR');
const _secondPortfolio = DepotPortfolio(id: 'p2', name: 'Two', currency: 'EUR');
DepotPeriodKey _key(DepotPeriod period, [String scope = DepotStore.allScope]) =>
    (scope: scope, period: period);

DepotTransaction _transaction(
  String id,
  DateTime date, {
  String holdingId = 'holding',
}) => DepotTransaction.fromJson(_portfolio.id, {
  'id': id,
  'type': 'dividend',
  'datetime': date.toIso8601String(),
  'amountNet': 10,
  'currency': 'EUR',
  'holdingId': holdingId,
})!;

class _FakeApi extends ParqetApi {
  _FakeApi() : super(clientId: 'test-client');

  List<DepotPortfolio> portfolioList = [_portfolio];
  final calls = <DepotPeriodKey>[];
  final activityCalls = <({String id, DateTime? since, String? holdingId})>[];
  Map<String, int> activityCounts = {};
  final periodGates = <DepotPeriod, Completer<void>>{};
  final periodStarted = <DepotPeriod, Completer<void>>{};
  Completer<void>? activitiesGate;
  final activitiesStarted = Completer<void>();
  List<DepotTransaction> transactions = [];
  DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(
    DateTime.now().millisecondsSinceEpoch,
  );
  bool complete = true;
  bool failActivities = false;
  bool emptyHoldings = false;
  int chartCount = 2;
  int portfolioCalls = 0;

  @override
  Future<List<DepotPortfolio>> portfolios() async {
    portfolioCalls++;
    return portfolioList;
  }

  @override
  Future<ParqetPerformance> performance({
    required DepotPeriodKey key,
    required List<String> portfolioIds,
    required String currency,
  }) async {
    calls.add(key);
    final started = periodStarted[key.period];
    if (started != null && !started.isCompleted) started.complete();
    await periodGates[key.period]?.future;
    final holding = DepotHolding.fromJson(key.scope, {'id': 'holding'});
    return ParqetPerformance(
      summary: DepotSummary.fromJson(
        key: key,
        currency: currency,
        syncedAt: timestamp,
        performance: const {
          'valuation': {'atIntervalEnd': 1234},
        },
      ),
      holdings: emptyHoldings ? [] : [holding],
      holdingPerformance: emptyHoldings
          ? []
          : [
              DepotHoldingPerformance(
                portfolioId: key.scope,
                holdingId: holding.id,
                period: key.period,
                gain: 12,
              ),
            ],
      chart: [
        for (var i = 0; i < chartCount; i++)
          DepotChartPoint(
            date: DateTime(2026, 1, i + 1),
            value: 100 + i.toDouble(),
            capital: 80,
            drawdown: 0,
          ),
      ],
      activityCounts: emptyHoldings ? const {} : activityCounts,
    );
  }

  @override
  Future<ParqetActivities> activities(
    String portfolioId, {
    DateTime? since,
    String? holdingId,
  }) async {
    activityCalls.add((id: portfolioId, since: since, holdingId: holdingId));
    if (!activitiesStarted.isCompleted) activitiesStarted.complete();
    await activitiesGate?.future;
    if (failActivities) {
      throw const ParqetException(ParqetErrorKind.network);
    }
    return ParqetActivities(
      items: [
        for (final t in transactions)
          if (holdingId == null || t.holdingId == holdingId) t,
      ],
      complete: since == null || complete,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = DepotStore.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });
  setUp(() async {
    await store.clear();
    await store.setClientId('test-client');
    FlutterSecureStorage.setMockInitialValues({});
    await ParqetAuth.clearTokens();
    FlutterSecureStorage.setMockInitialValues({
      'depot_parqet_access_token': 'test-access',
      'depot_parqet_refresh_token': 'test-refresh',
      'depot_parqet_expires_at':
          '${DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch}',
    });
  });
  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  test('publishes selected period before holdings and activities', () async {
    final api = _FakeApi();
    var published = false;
    await DepotParqetSync.run(
      api: api,
      period: DepotPeriod.year1,
      onPeriodReady: () async {
        published = true;
        expect(api.calls.map((k) => k.period), [DepotPeriod.year1]);
        expect(api.activityCalls, isEmpty);
        expect((await store.summary(_key(DepotPeriod.year1)))!.valueEnd, 1234);
        expect(await store.chart(_key(DepotPeriod.year1)), hasLength(2));
        expect(await store.lastSyncAt(), isNull);
      },
    );
    expect(published, isTrue);
    expect(api.portfolioCalls, 1);
    expect(api.calls.map((k) => k.period), [
      DepotPeriod.year1,
      DepotPeriod.max,
    ]);
    expect(await store.holdings(), hasLength(1));
    expect(await store.lastSyncAt(), isNotNull);
  });

  test(
    'selected Max is reused for holdings instead of requested twice',
    () async {
      final api = _FakeApi();
      await DepotParqetSync.run(api: api, period: DepotPeriod.max);
      expect(api.calls, [_key(DepotPeriod.max, 'p1')]);
      expect(await store.holdings(), hasLength(1));
      expect(await store.holdingPerformance(DepotPeriod.max), hasLength(1));
    },
  );

  test(
    'two portfolios request selected performance plus individual Max only',
    () async {
      final api = _FakeApi()..portfolioList = [_portfolio, _secondPortfolio];
      await DepotParqetSync.run(api: api);
      expect(api.calls, hasLength(5));
      expect(api.activityCalls, hasLength(2));
      expect(api.portfolioCalls, 1);
      expect(api.calls, contains(_key(DepotPeriod.today)));
      expect(api.calls, isNot(contains(_key(DepotPeriod.max))));
      expect(await store.holdings(), hasLength(2));
      expect(await store.holdingPerformance(DepotPeriod.today), hasLength(2));
    },
  );

  test(
    'an empty portfolio list clears the mirror without performance requests',
    () async {
      await DepotParqetSync.run(api: _FakeApi(), full: true);
      final api = _FakeApi()..portfolioList = [];
      await DepotParqetSync.run(api: api);
      expect(api.calls, isEmpty);
      expect(api.activityCalls, isEmpty);
      expect(await store.portfolios(), isEmpty);
      expect(await store.holdings(), isEmpty);
      expect(await store.summary(_key(DepotPeriod.year1)), isNull);
    },
  );

  test(
    'normal sync keeps its watermark regardless of the old daily setting',
    () async {
      final newest = DateTime(2026, 1, 20);
      final initial = _FakeApi()
        ..transactions = [
          _transaction('old', DateTime(2025, 1)),
          _transaction('latest', newest),
        ];
      await DepotParqetSync.run(api: initial);
      await DatabaseService.instance.setSetting(
        DepotTool.config.id,
        'parqet_activity_full_sync_at',
        '0',
      );
      final next = _FakeApi()
        ..complete = false
        ..transactions = [_transaction('new', DateTime(2026, 1, 21))];
      await DepotParqetSync.run(api: next);
      expect(
        next.activityCalls.single.since,
        newest.subtract(const Duration(days: 3)),
      );
      expect(await store.transactions(), hasLength(3));
    },
  );

  test('activity counts re-read only changed holdings, catching backdated and '
      'deleted bookings', () async {
    final a = _transaction('a', DateTime(2025, 1));
    final b = _transaction('b', DateTime(2026, 1, 20));
    final first = _FakeApi()
      ..activityCounts = {'holding': 2}
      ..transactions = [a, b];
    await DepotParqetSync.run(api: first);
    expect(first.activityCalls.single.since, isNull);
    expect(await store.transactions(), hasLength(2));

    final unchanged = _FakeApi()
      ..activityCounts = {'holding': 2}
      ..complete = false;
    await DepotParqetSync.run(api: unchanged);
    expect(unchanged.activityCalls.single.holdingId, isNull);
    expect(unchanged.activityCalls.single.since, isNotNull);
    expect(await store.transactions(), hasLength(2));

    final backdated = _FakeApi()
      ..activityCounts = {'holding': 3}
      ..complete = false
      ..transactions = [a, b, _transaction('late', DateTime(2025, 6))];
    await DepotParqetSync.run(api: backdated);
    expect(
      backdated.activityCalls.map((c) => c.holdingId),
      containsAll([null, 'holding']),
    );
    expect(await store.transactions(), hasLength(3));

    final deleted = _FakeApi()
      ..activityCounts = {'holding': 1}
      ..complete = false
      ..transactions = [b];
    await DepotParqetSync.run(api: deleted);
    expect((await store.transactions()).map((t) => t.id), ['b']);
  });

  test(
    'only explicit full sync rereads all periods and reconciles deletions',
    () async {
      final initial = _FakeApi()
        ..transactions = [_transaction('deleted', DateTime(2025, 1))];
      await DepotParqetSync.run(api: initial);
      final full = _FakeApi();
      await DepotParqetSync.run(api: full, full: true);
      expect(full.activityCalls.single.since, isNull);
      expect(
        full.calls.map((k) => k.period).toSet(),
        DepotPeriod.values.toSet(),
      );
      expect(full.calls, hasLength(7));
      expect(await store.transactions(), isEmpty);
    },
  );

  test(
    'partial refresh replaces fetched rows but preserves other periods',
    () async {
      final initial = _FakeApi()..timestamp = DateTime(2025);
      await DepotParqetSync.run(api: initial, full: true);
      final next = _FakeApi()
        ..chartCount = 1
        ..emptyHoldings = true;
      await DepotParqetSync.run(api: next);
      expect(
        (await store.summary(_key(DepotPeriod.year1)))!.syncedAt,
        DateTime(2025),
      );
      expect(await store.chart(_key(DepotPeriod.year1)), hasLength(2));
      expect(await store.chart(_key(DepotPeriod.today)), hasLength(1));
      expect(await store.holdingPerformance(DepotPeriod.today), isEmpty);
      expect(await store.holdings(), isEmpty);
    },
  );

  test(
    'portfolio removal prunes its cache and invalidates the combined cache',
    () async {
      final initial = _FakeApi()
        ..portfolioList = [_portfolio, _secondPortfolio];
      await DepotParqetSync.run(api: initial, full: true);
      final next = _FakeApi();
      await DepotParqetSync.run(api: next);
      expect(await store.summary(_key(DepotPeriod.year1, 'p2')), isNull);
      expect(await store.summary(_key(DepotPeriod.year1)), isNull);
      expect(await store.summary(_key(DepotPeriod.year1, 'p1')), isNotNull);
      expect(await store.holdings(), hasLength(1));
    },
  );

  test(
    'later failure keeps published performance without advancing last sync',
    () async {
      await DepotParqetSync.run(api: _FakeApi());
      final lastSync = await store.lastSyncAt();
      final next = _FakeApi()..failActivities = true;
      await expectLater(
        DepotParqetSync.run(api: next),
        throwsA(isA<ParqetException>()),
      );
      expect(
        (await store.summary(_key(DepotPeriod.today)))!.syncedAt,
        next.timestamp,
      );
      expect(await store.lastSyncAt(), lastSync);
    },
  );

  test(
    'lazy selection fetches only missing periods and reuses fresh cache',
    () async {
      final api = _FakeApi();
      final state = DepotPortfolioState(api: api);
      addTearDown(state.dispose);
      await state.ensureLoaded();
      expect(state.isConnected, isTrue);
      await state.sync();
      expect(api.calls, hasLength(2));
      await state.setPeriod(DepotPeriod.year1);
      expect(api.calls, hasLength(3));
      expect(state.summary!.period, DepotPeriod.year1);
      expect(api.activityCalls, hasLength(1));
      await state.setPeriod(DepotPeriod.today);
      await state.setPeriod(DepotPeriod.year1);
      expect(api.calls, hasLength(3));
      expect(state.isSyncing, isFalse);
    },
  );

  test(
    'stale cached values stay visible while the selected period refreshes',
    () async {
      final old = _FakeApi()..timestamp = DateTime(2025);
      await DepotParqetSync.run(api: old, full: true);
      final api = _FakeApi();
      final gate = Completer<void>();
      final started = Completer<void>();
      api.periodGates[DepotPeriod.year1] = gate;
      api.periodStarted[DepotPeriod.year1] = started;
      final state = DepotPortfolioState(api: api);
      addTearDown(state.dispose);
      await state.ensureLoaded();
      final selection = state.setPeriod(DepotPeriod.year1);
      await started.future;
      expect(state.summary!.syncedAt, DateTime(2025));
      expect(state.chart, hasLength(2));
      expect(state.isSyncing, isTrue);
      gate.complete();
      await selection;
      expect(state.summary!.syncedAt, api.timestamp);
      expect(api.calls, [_key(DepotPeriod.year1, 'p1')]);
    },
  );

  test(
    'selection changed during sync is refreshed after the core sync',
    () async {
      final api = _FakeApi()..activitiesGate = Completer<void>();
      final state = DepotPortfolioState(api: api);
      addTearDown(state.dispose);
      await state.ensureLoaded();
      final sync = state.sync();
      await api.activitiesStarted.future;
      expect(state.summary!.period, DepotPeriod.today);
      await state.setPeriod(DepotPeriod.year1);
      api.activitiesGate!.complete();
      await sync;
      expect(api.calls.map((k) => k.period), [
        DepotPeriod.today,
        DepotPeriod.max,
        DepotPeriod.year1,
      ]);
      expect(state.summary!.period, DepotPeriod.year1);
      expect(state.isSyncing, isFalse);
    },
  );

  test('slow earlier selections never replace the current period', () async {
    await DepotParqetSync.run(api: _FakeApi());
    final api = _FakeApi();
    final gate = Completer<void>();
    final started = Completer<void>();
    api.periodGates[DepotPeriod.year1] = gate;
    api.periodStarted[DepotPeriod.year1] = started;
    final state = DepotPortfolioState(api: api);
    addTearDown(state.dispose);
    await state.ensureLoaded();
    final first = state.setPeriod(DepotPeriod.year1);
    await started.future;
    await state.setPeriod(DepotPeriod.month1);
    gate.complete();
    await first;
    expect(state.period, DepotPeriod.month1);
    expect(state.summary!.period, DepotPeriod.month1);
  });

  test('revisiting a loading period shares the in-flight request', () async {
    await DepotParqetSync.run(api: _FakeApi());
    final api = _FakeApi();
    final gate = Completer<void>();
    final started = Completer<void>();
    api.periodGates[DepotPeriod.year1] = gate;
    api.periodStarted[DepotPeriod.year1] = started;
    final state = DepotPortfolioState(api: api);
    addTearDown(state.dispose);
    await state.ensureLoaded();
    final first = state.setPeriod(DepotPeriod.year1);
    await started.future;
    await state.setPeriod(DepotPeriod.today);
    final second = state.setPeriod(DepotPeriod.year1);
    gate.complete();
    await Future.wait([first, second]);
    expect(api.calls, [_key(DepotPeriod.year1, 'p1')]);
    expect(state.summary!.period, DepotPeriod.year1);
    expect(state.isSyncing, isFalse);
  });
}
