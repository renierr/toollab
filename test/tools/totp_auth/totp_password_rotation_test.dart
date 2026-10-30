import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/app_http_client.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/settings_service.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/tools/totp_auth/config.dart';
import 'package:tool_lab/tools/totp_auth/totp_account.dart';
import 'package:tool_lab/tools/totp_auth/totp_auth_state.dart';
import 'package:tool_lab/tools/totp_auth/totp_crypto.dart';
import 'package:tool_lab/tools/totp_auth/totp_sync_delegate.dart';
import 'package:tool_lab/tools/totp_auth/totp_vault_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final server = <String, Map<String, dynamic>>{};
  late TotpAuthState state;
  late AppState appState;
  late MockClient client;
  var failAfterWrite = false;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });
  setUp(() async {
    await DatabaseService.instance.close();
    FlutterSecureStorage.setMockInitialValues({});
    server.clear();
    failAfterWrite = false;
    client = MockClient((request) async {
      if (request.url.path == '/api/health') {
        return http.Response('{"status":"ok"}', 200);
      }
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'success': true,
            'full': true,
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
      var updated = 0;
      for (final item in body['records'] as List) {
        final record = Map<String, dynamic>.from(item as Map);
        final old = server[record['id']];
        if (old == null ||
            (record['updatedAt'] as int) > (old['updatedAt'] as int)) {
          server[record['id'] as String] = record;
          updated++;
        }
      }
      if (failAfterWrite) {
        failAfterWrite = false;
        return http.Response('interrupted', 503);
      }
      return http.Response(
        jsonEncode({'success': true, 'updatedCount': updated}),
        200,
      );
    });
    AppHttpClient.testClient = client;
    state = TotpAuthState();
    await state.ready;
    await state.setupVault('old shared password');
    appState = AppState(await SettingsService.init());
    await appState.saveSyncSettings(
      enabled: true,
      url: 'https://example.test',
      userId: 'user',
    );
  });
  tearDown(() {
    state.dispose();
    appState.dispose();
    AppHttpClient.testClient = null;
    client.close();
  });
  tearDownAll(() async => DatabaseService.instance.close());

  Future<void> sync() async {
    await SyncService.sync(
      baseUrl: 'https://example.test',
      userId: 'user',
      delegate: TotpSyncDelegate(),
      backendAlreadyChecked: true,
    );
  }

  TotpAccount account(String issuer, String secret) => TotpAccount.newAccount(
    issuer: issuer,
    accountName: 'user',
    secret: secret,
  );

  test(
    'interrupted backend rotation resumes after reopening the vault',
    () async {
      await state.addAccount(account('First', 'JBSWY3DPEHPK3PXP'));
      await state.addAccount(account('Second', 'KRSXG5CTMVRXEZLU'));
      await sync();
      await state.lockController.setAutomatic(true);
      failAfterWrite = true;
      await expectLater(
        state.changePassword(
          appState,
          'old shared password',
          'new shared password',
        ),
        throwsA(
          isA<SyncFailures>().having(
            (error) => error.failures.values.single,
            'failure',
            isA<StateError>(),
          ),
        ),
      );
      expect(state.rotationPending, isTrue);
      expect(await TotpSyncDelegate().isReadyToSync(), isFalse);
      await expectLater(
        state.addAccount(account('Blocked', 'JBSWY3DPEHPK3PXP')),
        throwsStateError,
      );
      final journal = await DatabaseService.instance.getSetting(
        TotpAuthTool.config.id,
        TotpVaultStore.rotationSetting,
      );
      expect(journal, isNot(contains('new shared password')));
      state.dispose();
      state = TotpAuthState();
      await state.ready;
      expect(state.rotationPending, isTrue);
      expect(await state.unlockVault('old shared password'), isTrue);
      await state.resumePasswordRotation(appState);
      expect(state.rotationPending, isFalse);
      expect(state.lockController.automatic, isFalse);
      state.lockController.lock();
      expect(await state.unlockVault('old shared password'), isFalse);
      expect(await state.unlockVault('new shared password'), isTrue);
      for (final record in server.values) {
        final payload = (record['data'] as Map)['payload'] as String;
        final clear = await TotpCrypto.decrypt(payload, 'new shared password');
        expect(jsonDecode(clear)['id'], record['id']);
      }
      await sync();
      await state.reload();
      expect(state.accounts, hasLength(2));
    },
  );

  test('wrong current password never changes local or backend data', () async {
    await state.addAccount(account('Server', 'JBSWY3DPEHPK3PXP'));
    await sync();
    final before = jsonEncode(server);
    await expectLater(
      state.changePassword(appState, 'wrong password', 'new shared password'),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
    expect(jsonEncode(server), before);
    expect(state.rotationPending, isFalse);
    expect(state.syncPassword, 'old shared password');
  });

  test(
    'lost final response can be resumed after backend already changed',
    () async {
      final only = account('Only', 'JBSWY3DPEHPK3PXP');
      await state.addAccount(only);
      await sync();
      failAfterWrite = true;
      await expectLater(
        state.changePassword(
          appState,
          'old shared password',
          'new shared password',
        ),
        throwsA(isA<SyncFailures>()),
      );
      final payload = (server[only.id]!['data'] as Map)['payload'] as String;
      expect(
        await TotpCrypto.decrypt(payload, 'new shared password'),
        contains('Only'),
      );
      expect(state.rotationPending, isTrue);
      await state.resumePasswordRotation(appState);
      expect(state.syncPassword, 'new shared password');
      expect(state.rotationPending, isFalse);
    },
  );

  test(
    'disabled tool sync blocks password rotation before any changes',
    () async {
      await state.addAccount(account('Server', 'JBSWY3DPEHPK3PXP'));
      await sync();
      final before = jsonEncode(server);
      await appState.setToolSyncEnabled(TotpAuthTool.config.id, false);
      await expectLater(
        state.changePassword(
          appState,
          'old shared password',
          'new shared password',
        ),
        throwsStateError,
      );
      expect(jsonEncode(server), before);
      expect(state.rotationPending, isFalse);
      expect(state.syncPassword, 'old shared password');
    },
  );

  test('resume refuses unrelated encrypted records without writing', () async {
    final first = account('First', 'JBSWY3DPEHPK3PXP');
    final second = account('Second', 'KRSXG5CTMVRXEZLU');
    await state.addAccount(first);
    await state.addAccount(second);
    await sync();
    failAfterWrite = true;
    await expectLater(
      state.changePassword(
        appState,
        'old shared password',
        'new shared password',
      ),
      throwsA(isA<SyncFailures>()),
    );
    server[second.id]!['data'] = {
      'version': 2,
      'payload': await TotpCrypto.encrypt(
        jsonEncode(second.toJson()),
        'unrelated password',
      ),
    };
    final before = jsonEncode(server);
    await expectLater(
      state.resumePasswordRotation(appState),
      throwsA(
        isA<SyncFailures>().having(
          (error) => error.failures.values.single,
          'failure',
          isA<SyncPasswordMismatchException>(),
        ),
      ),
    );
    expect(jsonEncode(server), before);
    expect(state.rotationPending, isTrue);
  });

  test(
    'other device verifies new password and keeps offline accounts',
    () async {
      await state.addAccount(account('Server', 'JBSWY3DPEHPK3PXP'));
      await sync();
      final oldEnvelope = await DatabaseService.instance.getSetting(
        TotpAuthTool.config.id,
        TotpVaultStore.keyEnvelopeSetting,
      );
      await state.changePassword(
        appState,
        'old shared password',
        'new shared password',
      );
      state.dispose();
      await DatabaseService.instance.setSetting(
        TotpAuthTool.config.id,
        TotpVaultStore.keyEnvelopeSetting,
        oldEnvelope!,
      );
      state = TotpAuthState();
      await state.ready;
      expect(await state.unlockVault('old shared password'), isTrue);
      await state.addAccount(account('Offline', 'KRSXG5CTMVRXEZLU'));
      await expectLater(
        state.adoptBackendPassword(appState, 'wrong password'),
        throwsA(
          isA<SyncFailures>().having(
            (error) => error.failures.values.single,
            'failure',
            isA<SyncPasswordMismatchException>(),
          ),
        ),
      );
      expect(state.syncPassword, 'old shared password');
      expect(state.accounts, hasLength(2));
      await state.adoptBackendPassword(appState, 'new shared password');
      expect(state.syncPassword, 'new shared password');
      await sync();
      await state.reload();
      expect(
        state.accounts.map((account) => account.issuer),
        containsAll(['Server', 'Offline']),
      );
      expect(server, hasLength(3));
    },
  );

  test('empty backend still detects an old device password', () async {
    final oldEnvelope = await DatabaseService.instance.getSetting(
      TotpAuthTool.config.id,
      TotpVaultStore.keyEnvelopeSetting,
    );
    await state.changePassword(
      appState,
      'old shared password',
      'new shared password',
    );
    expect(server.keys, [TotpCrypto.syncCheckRecordId]);
    state.dispose();
    await DatabaseService.instance.setSetting(
      TotpAuthTool.config.id,
      TotpVaultStore.keyEnvelopeSetting,
      oldEnvelope!,
    );
    state = TotpAuthState();
    await state.ready;
    expect(await state.unlockVault('old shared password'), isTrue);
    await expectLater(sync(), throwsA(isA<SyncPasswordMismatchException>()));
    await state.adoptBackendPassword(appState, 'new shared password');
    await sync();
    expect(state.accounts, isEmpty);
  });

  test('a second password change rotates the existing check record', () async {
    await state.addAccount(account('Server', 'JBSWY3DPEHPK3PXP'));
    await state.changePassword(
      appState,
      'old shared password',
      'new shared password',
    );
    await state.changePassword(
      appState,
      'new shared password',
      'third shared password',
    );
    await sync();
    await state.reload();
    expect(state.accounts, hasLength(1));
    expect(server, hasLength(2));
    final check = server[TotpCrypto.syncCheckRecordId]!;
    final payload = (check['data'] as Map)['payload'] as String;
    expect(
      jsonDecode(
        await TotpCrypto.decrypt(payload, 'third shared password'),
      )['id'],
      TotpCrypto.syncCheckRecordId,
    );
  });
}
