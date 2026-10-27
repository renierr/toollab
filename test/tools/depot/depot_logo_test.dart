import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/depot/depot_logo_downloader.dart';
import 'package:tool_lab/tools/depot/depot_logo_state.dart';
import 'package:tool_lab/tools/depot/depot_dividend_state.dart';
import 'package:tool_lab/tools/depot/depot_store.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/models/depot_dividend.dart';
import 'package:tool_lab/tools/depot/models/depot_holding_logo.dart';
import 'package:tool_lab/tools/depot/models/depot_portfolio.dart';
import 'package:tool_lab/tools/depot/widgets/depot_holding_avatar.dart';
import 'package:tool_lab/tools/depot/widgets/depot_logo_settings.dart';

import 'offline_test_support.dart';

final _png = Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2)));

class _Downloader extends DepotLogoDownloader {
  final calls = <String>[];
  final failures = <String>{};
  Completer<void>? gate;
  final started = Completer<void>();

  @override
  Future<Uint8List> download(String url) async {
    calls.add(url);
    if (!started.isCompleted) started.complete();
    await gate?.future;
    if (failures.contains(url)) throw const FormatException('Unavailable logo');
    return _png;
  }
}

DepotHolding _holding(String id, {String? isin, String? logo}) =>
    DepotHolding.fromJson('p1', {
      'id': id,
      'asset': {'type': 'security', 'name': id, 'isin': isin},
      'logo': logo,
    });

Future<void> _holdings(List<DepotHolding> holdings) =>
    DepotStore.instance.replaceAll(
      portfolios: const [
        DepotPortfolio(id: 'p1', name: 'Test', currency: 'EUR'),
      ],
      holdings: holdings,
      holdingPerformance: [],
      transactions: [],
      summaries: [],
      charts: {},
      completeActivityPortfolios: {},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  blockDepotNetwork();
  final store = DepotStore.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });
  setUp(() async {
    await store.clear();
  });
  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  test('uses small PNG URLs without changing other provider URLs', () {
    final uri = DepotLogoDownloader.imageUri(
      'https://image.parqet.com/security/US88160R1014?style=round',
    );
    expect(uri.queryParameters, {
      'style': 'round',
      'format': 'png',
      'size': '96',
    });
    expect(
      DepotLogoDownloader.imageUri('https://example.com/logo.png').query,
      '',
    );
    expect(
      () => DepotLogoDownloader.imageUri('http://example.com/logo'),
      throwsFormatException,
    );
    expect(
      () => DepotLogoDownloader.imageUri('https://user@host/logo'),
      throwsFormatException,
    );
  });

  test('downloads a valid image without sending account credentials', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], isNull);
      expect(request.headers['User-Agent'], 'ToolLab');
      expect(request.url.queryParameters['format'], 'png');
      return http.Response.bytes(
        _png,
        200,
        headers: {'content-type': 'image/png'},
      );
    });
    addTearDown(client.close);
    final bytes = await DepotLogoDownloader(
      client: client,
    ).download('https://image.parqet.com/security/US88160R1014');
    expect(bytes, _png);
  });

  test(
    'rejects errors, non-images, oversized bodies and oversized dimensions',
    () async {
      for (final response in [
        http.Response('Forbidden', 403),
        http.Response('<html>Not an image</html>', 200),
        http.Response.bytes(Uint8List(DepotLogoDownloader.maxBytes + 1), 200),
        http.Response.bytes(
          img.encodePng(img.Image(width: 513, height: 1)),
          200,
        ),
      ]) {
        final client = MockClient((request) async => response);
        addTearDown(client.close);
        await expectLater(
          DepotLogoDownloader(
            client: client,
          ).download('https://example.com/logo'),
          throwsA(isA<Exception>()),
        );
      }
    },
  );

  test(
    'downloads only on demand, deduplicates assets and skips saved logos',
    () async {
      await _holdings([
        _holding('one', isin: 'US88160R1014', logo: 'https://example.com/one'),
        _holding(
          'duplicate',
          isin: 'US88160R1014',
          logo: 'https://example.com/one',
        ),
        _holding('two', logo: 'https://example.com/two'),
        _holding('no-logo'),
      ]);
      final downloader = _Downloader();
      final state = DepotLogoState(downloader: downloader);
      addTearDown(state.dispose);
      await state.ensureLoaded();
      expect(downloader.calls, isEmpty);
      await state.downloadMissing();
      expect(downloader.calls, hasLength(2));
      expect(state.total, 2);
      expect(state.completed, 2);
      expect(state.failed, 0);
      expect(state.cachedCount, 2);
      expect(state.bytesFor('US88160R1014'), _png);
      await state.downloadMissing();
      expect(downloader.calls, hasLength(2));
      final restarted = DepotLogoState(downloader: downloader);
      addTearDown(restarted.dispose);
      await restarted.ensureLoaded();
      expect(restarted.cachedCount, 2);
      expect(restarted.bytesFor('US88160R1014'), _png);
      await restarted.downloadMissing();
      expect(downloader.calls, hasLength(2));
    },
  );

  test(
    'logo cache survives mirror refreshes without advancing sync itself',
    () async {
      final state = DepotLogoState(downloader: _Downloader());
      addTearDown(state.dispose);
      await state.ensureLoaded();
      await _holdings([_holding('one', logo: 'https://example.com/one')]);
      final lastSync = await store.lastSyncAt();
      await state.downloadMissing();
      expect(await store.lastSyncAt(), lastSync);
      await _holdings([]);
      expect(await store.holdingLogos(), hasLength(1));
      await store.clear();
      state.reset();
      expect(await store.holdingLogos(), isEmpty);
      expect(state.cachedCount, 0);
    },
  );

  test(
    'failed logos are retryable and never replace successful cache entries',
    () async {
      await _holdings([
        _holding('one', logo: 'https://example.com/one'),
        _holding('two', logo: 'https://example.com/two'),
      ]);
      final downloader = _Downloader()..failures.add('https://example.com/two');
      final state = DepotLogoState(downloader: downloader);
      addTearDown(state.dispose);
      await state.downloadMissing();
      expect(state.cachedCount, 1);
      expect(state.failed, 1);
      expect(state.isFetching, isFalse);
      downloader.failures.clear();
      await state.downloadMissing();
      expect(state.cachedCount, 2);
      expect(
        downloader.calls.where((url) => url.endsWith('/one')),
        hasLength(1),
      );
    },
  );

  test('concurrent button taps share a single run', () async {
    await _holdings([_holding('one', logo: 'https://example.com/one')]);
    final downloader = _Downloader()..gate = Completer<void>();
    final state = DepotLogoState(downloader: downloader);
    addTearDown(state.dispose);
    final first = state.downloadMissing();
    await downloader.started.future;
    await state.downloadMissing();
    expect(downloader.calls, hasLength(1));
    downloader.gate!.complete();
    await first;
    expect(state.cachedCount, 1);
  });

  test('reset prevents an in-flight download repopulating the cache', () async {
    await _holdings([_holding('one', logo: 'https://example.com/one')]);
    final downloader = _Downloader()..gate = Completer<void>();
    final state = DepotLogoState(downloader: downloader);
    addTearDown(state.dispose);
    final first = state.downloadMissing();
    await downloader.started.future;
    await store.clear();
    state.reset();
    downloader.gate!.complete();
    await first;
    expect(state.cachedCount, 0);
    expect(await store.holdingLogos(), isEmpty);
  });

  test('reducing the memory cache is silent and reloads saved logos', () async {
    await store.saveHoldingLogo(
      DepotHoldingLogo(
        key: 'CACHE',
        sourceUrl: 'https://example.com/logo',
        bytes: _png,
        fetchedAt: DateTime(2026),
      ),
    );
    final state = DepotLogoState(downloader: _Downloader());
    addTearDown(state.dispose);
    await state.ensureLoaded();
    var notifications = 0;
    state.addListener(() => notifications++);
    expect(state.bytesFor('CACHE'), _png);
    state.reduceCache();
    expect(notifications, 0);
    expect(state.bytesFor('CACHE'), isNull);
    expect(await store.holdingLogos(), hasLength(1));
    await state.ensureLoaded();
    expect(state.bytesFor('CACHE'), _png);
    expect(notifications, 1);
  });

  test('reducing dividend memory keeps the database cache', () async {
    final fetchedAt = DateTime(2026, 1, 1);
    await store.saveDividendAsset(
      DepotDividendAsset(
        key: 'CACHE',
        symbol: 'CACHE',
        currency: 'EUR',
        fxCurrency: 'EUR',
        fxRate: 1,
        fetchedAt: fetchedAt,
      ),
    );
    final state = DepotDividendState();
    addTearDown(state.dispose);
    await state.ensureLoaded();
    expect(state.fetchedAt, fetchedAt);
    state.reduceCache();
    expect(state.fetchedAt, isNull);
    expect((await store.dividendAssets()).containsKey('CACHE'), isTrue);
    await state.ensureLoaded();
    expect(state.fetchedAt, fetchedAt);
  });

  testWidgets('avatars and settings read only local bytes', (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final downloader = _Downloader();
    late DepotLogoState state;
    await tester.runAsync(() async {
      await store.saveHoldingLogo(
        DepotHoldingLogo(
          key: 'saved',
          sourceUrl: 'https://example.com/logo',
          bytes: _png,
          fetchedAt: DateTime.now(),
        ),
      );
      state = DepotLogoState(downloader: downloader);
      await state.ensureLoaded();
    });
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  DepotHoldingAvatar(name: 'Saved', colorSeed: 'saved'),
                  DepotHoldingAvatar(name: 'No Logo', colorSeed: 'missing'),
                  DepotLogoSettings(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.cover);
    expect(
      tester.getSize(find.byType(Image)),
      tester.getSize(find.byType(DepotHoldingAvatar).first),
    );
    final box = tester.widget<Container>(
      find
          .ancestor(of: find.byType(Image), matching: find.byType(Container))
          .first,
    );
    expect(box.clipBehavior, Clip.antiAlias);
    expect(
      (box.decoration! as BoxDecoration).borderRadius,
      BorderRadius.circular(9),
    );
    expect(find.text('NL'), findsOneWidget);
    expect(find.text('1 logo saved on this device'), findsOneWidget);
    expect(downloader.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
