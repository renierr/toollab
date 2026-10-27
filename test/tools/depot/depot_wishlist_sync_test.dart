import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/app_http_client.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/tools/depot/config.dart';
import 'package:tool_lab/tools/depot/depot_store.dart';
import 'package:tool_lab/tools/depot/depot_wishlist_state.dart';
import 'package:tool_lab/tools/depot/depot_wishlist_sync_delegate.dart';
import 'package:tool_lab/tools/depot/models/depot_wishlist.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = DepotStore.instance;
  final server = <String, Map<String, dynamic>>{};
  var failPush = false;
  late MockClient client;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
    final db = await DatabaseService.instance.getToolDatabase(
      DepotTool.config.id,
    );
    await db.execute('''
      CREATE TABLE ${db.nameTable('wishlist_items')} (
        symbol TEXT PRIMARY KEY, name TEXT NOT NULL, quote_type TEXT NOT NULL,
        exchange TEXT NOT NULL, currency TEXT NOT NULL, added_price REAL,
        added_at INTEGER NOT NULL, isin TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE ${db.nameTable('wishlist_logos')} (
        asset_key TEXT PRIMARY KEY, source_url TEXT NOT NULL,
        data BLOB NOT NULL, fetched_at INTEGER NOT NULL
      )
    ''');
    await db.insert('wishlist_items', {
      'symbol': 'AAPL',
      'name': 'Apple',
      'quote_type': 'EQUITY',
      'exchange': 'NASDAQ',
      'currency': 'USD',
      'added_price': 125.5,
      'added_at': 1000,
      'isin': 'US0378331005',
    });
    await DatabaseService.instance.setSetting(
      DepotTool.config.id,
      '_db_schema_version',
      '9',
    );
    client = MockClient((request) async {
      final path = request.url.path;
      expect(path, startsWith('/api/sync/${DepotTool.config.id}-user'));
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'success': true,
            'records': [
              for (final entry in server.entries)
                {
                  'id': entry.key,
                  'updatedAt': entry.value['updatedAt'],
                  'deleted': entry.value['deleted'],
                },
            ],
          }),
          200,
        );
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (path.endsWith('/pull')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'records': [for (final id in body['ids'] as List) server[id]],
          }),
          200,
        );
      }
      if (failPush) return http.Response('offline', 503);
      for (final record in body['records'] as List) {
        server[record['id'] as String] = Map<String, dynamic>.from(
          record as Map,
        );
      }
      return http.Response('{"success":true}', 200);
    });
    AppHttpClient.testClient = client;
  });

  tearDownAll(() async {
    AppHttpClient.testClient = null;
    client.close();
    await DatabaseService.instance.close();
  });

  Future<Map<String, int>> sync() => SyncService.sync(
    baseUrl: 'https://example.test',
    userId: 'user',
    delegate: DepotWishlistSyncDelegate(),
    backendAlreadyChecked: true,
  );

  test('migrates existing entries and pushes complete wishlist data', () async {
    expect(DepotTool.config.syncDelegateFactory, isNotNull);
    expect((await store.wishlistItems()).single.isin, 'US0378331005');
    final result = await sync();
    expect(result['pushed'], 1);
    expect(server['AAPL'], {
      'id': 'AAPL',
      'updatedAt': 1000,
      'deleted': false,
      'data': {
        'shortId': 'AAPL',
        'name': 'Apple',
        'quoteType': 'EQUITY',
        'exchange': 'NASDAQ',
        'currency': 'USD',
        'isin': 'US0378331005',
        'addedPrice': 125.5,
        'addedAt': 1000,
      },
    });
  });

  test(
    'pulls updates, refreshes loaded state and propagates deletions',
    () async {
      final state = DepotWishlistState(
        quoteLoader: (_) async => throw StateError('offline'),
        logoLoader: (_) async => throw StateError('offline'),
      );
      addTearDown(state.dispose);
      await state.ensureLoaded();
      final updated = Completer<void>();
      state.addListener(() {
        if (state.items.any((item) => item.name == 'Apple updated') &&
            !updated.isCompleted) {
          updated.complete();
        }
      });
      server['AAPL'] = {
        'id': 'AAPL',
        'updatedAt': 2000,
        'deleted': false,
        'data': {
          'shortId': 'AAPL',
          'name': 'Apple updated',
          'quoteType': 'EQUITY',
          'exchange': 'NASDAQ',
          'currency': 'USD',
          'addedAt': 1000,
        },
      };
      expect((await sync())['pulled'], 1);
      await updated.future.timeout(const Duration(seconds: 5));
      expect(state.items.single.name, 'Apple updated');
      await store.deleteWishlistItem('AAPL');
      expect(await store.wishlistItems(), isEmpty);
      failPush = true;
      await expectLater(sync(), throwsException);
      expect((await store.wishlistSyncRecords()).single.deleted, isTrue);
      failPush = false;
      expect((await sync())['pushed'], 1);
      expect(server['AAPL']!['deleted'], isTrue);
      expect(await store.wishlistSyncRecords(), isEmpty);
    },
  );

  test('remote deletion removes entries but not newer local edits', () async {
    final item = DepotWishlistItem(
      symbol: 'MSFT',
      name: 'Microsoft',
      quoteType: 'EQUITY',
      exchange: 'NASDAQ',
      currency: 'USD',
      addedAt: DateTime(2026),
    );
    await store.saveWishlistItem(item);
    final delegate = DepotWishlistSyncDelegate();
    final observed =
        (await delegate.getLocalSyncRecords()).single['updatedAt'] as int;
    await store.saveWishlistItem(item.withIsin('US5949181045'));
    await delegate.finalizeLocalSync('MSFT', true);
    expect((await store.wishlistItems()).single.isin, 'US5949181045');
    server['MSFT'] = {
      'id': 'MSFT',
      'updatedAt': observed + 100000,
      'deleted': true,
    };
    expect((await sync())['deleted'], 1);
    expect(await store.wishlistItems(), isEmpty);
  });
}
