import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/helpers/tool_vault_crypto.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/totp_auth/config.dart';
import 'package:tool_lab/tools/totp_auth/totp_account.dart';
import 'package:tool_lab/tools/totp_auth/totp_auth_state.dart';
import 'package:tool_lab/tools/totp_auth/totp_vault_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });
  setUp(() async => DatabaseService.instance.close());
  tearDownAll(() async => DatabaseService.instance.close());

  test(
    'stores the complete account encrypted and detects metadata tampering',
    () async {
      final key = await ToolVaultCrypto.newDataKey();
      final store = TotpVaultStore();
      final account = TotpAccount.newAccount(
        issuer: 'Private service',
        accountName: 'person@example.com',
        secret: 'JBSWY3DPEHPK3PXP',
      );
      await store.save(account, key);
      final db = await DatabaseService.instance.getToolDatabase(
        TotpAuthTool.config.id,
      );
      final row = (await db.query('vault_accounts')).single;
      final raw = jsonEncode(row);
      expect(raw, isNot(contains(account.issuer)));
      expect(raw, isNot(contains(account.accountName)));
      expect(raw, isNot(contains(account.secret)));
      final restored = (await store.load(key)).single;
      expect(restored.id, account.id);
      expect(restored.secret, account.secret);
      expect(restored.accountName, account.accountName);
      await db.update(
        'vault_accounts',
        {'deleted': 1},
        where: 'id = ?',
        whereArgs: [account.id],
      );
      await expectLater(store.load(key), throwsFormatException);
    },
  );

  test(
    'migration rolls back on conflict and encrypts accounts atomically',
    () async {
      final key = await ToolVaultCrypto.newDataKey();
      final wrapped = await ToolVaultCrypto.wrapKey(key, 'migration password');
      final account = TotpAccount.newAccount(
        issuer: 'Private service',
        accountName: 'person@example.com',
        secret: 'JBSWY3DPEHPK3PXP',
      );
      await TotpAuthState.migrateDb();
      final db = await DatabaseService.instance.getToolDatabase(
        TotpAuthTool.config.id,
      );
      await db.insert('accounts', account.toMap());
      final store = TotpVaultStore();
      await store.save(account, key);
      await expectLater(
        store.migrateLegacy(key, wrapped),
        throwsA(isA<DatabaseException>()),
      );
      expect(await db.query('accounts'), hasLength(1));
      expect(
        await DatabaseService.instance.getSetting(
          TotpAuthTool.config.id,
          TotpVaultStore.keyEnvelopeSetting,
        ),
        isNull,
      );
      await store.delete(account.id);
      await store.migrateLegacy(key, wrapped);
      expect((await store.load(key)).single.secret, account.secret);
      expect(
        await DatabaseService.instance.getSetting(
          TotpAuthTool.config.id,
          TotpVaultStore.keyEnvelopeSetting,
        ),
        wrapped,
      );
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        [db.nameTable('accounts')],
      );
      expect(tables, isEmpty);
    },
  );
}
