import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/totp_auth/config.dart';
import 'package:tool_lab/tools/totp_auth/totp_account.dart';
import 'package:tool_lab/tools/totp_auth/totp_auth_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getTemporaryDirectory') return '/tmp/opencode';
          return null;
        });
  });
  setUp(() async {
    await DatabaseService.instance.close();
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDownAll(() async {
    await DatabaseService.instance.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'full database export blocks plaintext, then omits migrated secrets',
    () async {
      await TotpAuthState.migrateDb();
      final db = await DatabaseService.instance.getToolDatabase(
        TotpAuthTool.config.id,
      );
      final account = TotpAccount.newAccount(
        issuer: 'Private service',
        accountName: 'person@example.com',
        secret: 'JBSWY3DPEHPK3PXP',
      );
      await db.insert('accounts', account.toMap());
      await expectLater(
        DatabaseService.instance.getDatabaseBytes(),
        throwsA(isA<PlaintextAuthenticatorBackupException>()),
      );
      final state = TotpAuthState();
      await state.ready;
      addTearDown(state.dispose);
      await state.setupVault('strong sync password');
      final bytes = await DatabaseService.instance.getDatabaseBytes();
      final raw = latin1.decode(bytes);
      expect(raw, isNot(contains(account.secret)));
      expect(raw, isNot(contains(account.accountName)));
      expect(raw, isNot(contains(account.issuer)));
      expect(raw, isNot(contains('strong sync password')));
    },
  );
}
