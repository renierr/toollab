import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/app_http_client.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/tools/totp_auth/config.dart';
import 'package:tool_lab/tools/totp_auth/totp_account.dart';
import 'package:tool_lab/tools/totp_auth/totp_auth_state.dart';
import 'package:tool_lab/tools/totp_auth/totp_crypto.dart';
import 'package:tool_lab/tools/totp_auth/totp_sync_delegate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final server = <String, Map<String, dynamic>>{};
  late MockClient client;
  var pushes = 0;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });
  setUp(() async {
    await DatabaseService.instance.close();
    server.clear();
    pushes = 0;
    FlutterSecureStorage.setMockInitialValues({
      TotpCrypto.syncPasswordKey: 'shared password',
    });
    client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'success': true,
            'records': [
              for (final record in server.values)
                {
                  'id': record['id'],
                  'updatedAt': record['updatedAt'],
                  'deleted': record['deleted'],
                },
            ],
          }),
          200,
        );
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (request.url.path.endsWith('/pull')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'records': [
              for (final id in body['ids'] as List)
                if (server.containsKey(id)) server[id],
            ],
          }),
          200,
        );
      }
      pushes++;
      for (final value in body['records'] as List) {
        final record = Map<String, dynamic>.from(value as Map);
        server[record['id'] as String] = record;
      }
      return http.Response('{"success":true}', 200);
    });
    AppHttpClient.testClient = client;
  });
  tearDown(() {
    AppHttpClient.testClient = null;
    client.close();
  });
  tearDownAll(() async => DatabaseService.instance.close());

  Future<Map<String, int>> sync() => SyncService.sync(
    baseUrl: 'https://example.test',
    userId: 'user',
    delegate: TotpSyncDelegate(),
    backendAlreadyChecked: true,
  );

  Future<void> put(TotpAccount account) async {
    await TotpAuthState.migrateDb();
    final db = await DatabaseService.instance.getToolDatabase(
      TotpAuthTool.config.id,
    );
    await db.insert(
      'accounts',
      account.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  test(
    'encrypts the whole record and restores it with the same password',
    () async {
      final account = TotpAccount.newAccount(
        issuer: 'Private issuer',
        accountName: 'alice',
        secret: 'JBSWY3DPEHPK3PXP',
      );
      await put(account);
      expect((await sync())['pushed'], 1);
      final wire = jsonEncode(server[account.id]);
      expect(wire, isNot(contains('Private issuer')));
      expect(wire, isNot(contains('alice')));
      expect(wire, isNot(contains(account.secret)));
      final db = await DatabaseService.instance.getToolDatabase(
        TotpAuthTool.config.id,
      );
      await db.delete('accounts');
      expect((await sync())['pulled'], 1);
      final restored = TotpAccount.fromMap((await db.query('accounts')).single);
      expect(restored.issuer, account.issuer);
      expect(restored.accountName, account.accountName);
      expect(restored.secret, account.secret);
    },
  );

  test(
    'wrong password blocks uploads even when local record is newer',
    () async {
      final account = TotpAccount.newAccount(
        issuer: 'Private',
        accountName: 'alice',
        secret: 'JBSWY3DPEHPK3PXP',
      );
      await put(account);
      await sync();
      final original = jsonEncode(server);
      account.updatedAt = account.updatedAt.add(const Duration(seconds: 5));
      await put(account);
      FlutterSecureStorage.setMockInitialValues({
        TotpCrypto.syncPasswordKey: 'wrong password',
      });
      await expectLater(sync(), throwsA(isA<SyncPasswordMismatchException>()));
      expect(pushes, 1);
      expect(jsonEncode(server), original);
    },
  );

  test('old or plaintext remote data is rejected before upload', () async {
    final account = TotpAccount.newAccount(
      issuer: 'Private',
      accountName: 'alice',
      secret: 'JBSWY3DPEHPK3PXP',
    );
    await put(account);
    server['old'] = {
      'id': 'old',
      'updatedAt': 1,
      'deleted': false,
      'data': {'secret': 'plaintext'},
    };
    await expectLater(sync(), throwsA(isA<SyncUnsupportedPayloadException>()));
    expect(pushes, 0);
  });

  test('direct sync is blocked without password', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await expectLater(sync(), throwsStateError);
    expect(pushes, 0);
  });

  test('remote deletion removes the local account', () async {
    final account = TotpAccount.newAccount(
      issuer: 'Private',
      accountName: 'alice',
      secret: 'JBSWY3DPEHPK3PXP',
    );
    await put(account);
    await sync();
    server[account.id] = {
      'id': account.id,
      'updatedAt': account.updatedAt.millisecondsSinceEpoch + 1000,
      'deleted': true,
    };
    expect((await sync())['deleted'], 1);
    final db = await DatabaseService.instance.getToolDatabase(
      TotpAuthTool.config.id,
    );
    expect(await db.query('accounts'), isEmpty);
  });
}
