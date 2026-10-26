import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/totp_auth/config.dart';
import 'package:tool_lab/tools/totp_auth/totp_auth_state.dart';

Future<TotpAuthState> _initialize() async {
  final ready = Completer<void>();
  final state = TotpAuthState();
  var notifications = 0;
  void listener() {
    if (++notifications == 2) ready.complete();
  }

  state.addListener(listener);
  await ready.future.timeout(const Duration(seconds: 5));
  state.removeListener(listener);
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });
  setUp(() async {
    await DatabaseService.instance.close();
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  test('fresh startup creates the namespaced accounts table', () async {
    final state = await _initialize();
    addTearDown(state.dispose);
    expect(state.accounts, isEmpty);
    final db = await DatabaseService.instance.getToolDatabase(
      TotpAuthTool.config.id,
    );
    expect(await db.query('accounts'), isEmpty);
  });

  test('version 1 startup preserves rows from the unprefixed table', () async {
    final db = await DatabaseService.instance.getToolDatabase(
      TotpAuthTool.config.id,
    );
    await db.migrate(
      currentVersion: 1,
      onMigrate: (txn, oldVersion, newVersion) async {
        await txn.execute('''
          CREATE TABLE accounts (
            id TEXT PRIMARY KEY, issuer TEXT NOT NULL,
            account_name TEXT NOT NULL, secret TEXT NOT NULL,
            algorithm TEXT NOT NULL, digits INTEGER NOT NULL,
            period INTEGER NOT NULL, created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL, deleted INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await txn.rawInsert(
          'INSERT INTO accounts VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            'legacy',
            'Example',
            'user',
            'JBSWY3DPEHPK3PXP',
            'SHA1',
            6,
            30,
            0,
            0,
            0,
          ],
        );
      },
    );
    final first = await _initialize();
    expect(first.accounts.single.id, 'legacy');
    first.dispose();
    final second = await _initialize();
    addTearDown(second.dispose);
    expect(second.accounts.single.id, 'legacy');
    expect(await db.query('accounts'), hasLength(1));
  });
}
