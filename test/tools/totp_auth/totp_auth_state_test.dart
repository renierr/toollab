import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/totp_auth/totp.dart';
import 'package:tool_lab/tools/totp_auth/totp_account.dart';
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

TotpAccount _account(String issuer, String account, String secret) {
  return TotpAccount.newAccount(
    issuer: issuer,
    accountName: account,
    secret: secret,
  );
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

  test('accounts persist with all typed fields', () async {
    final state = await _initialize();
    final account = TotpAccount.newAccount(
      issuer: 'Example',
      accountName: 'alice',
      secret: 'JBSWY3DPEHPK3PXP',
      algorithm: TotpAlgorithm.sha256,
      digits: 8,
      period: 60,
    );
    await state.addAccount(account);
    state.dispose();

    final reloaded = await _initialize();
    addTearDown(reloaded.dispose);
    final stored = reloaded.accounts.single;
    expect(stored.issuer, 'Example');
    expect(stored.accountName, 'alice');
    expect(stored.algorithm, TotpAlgorithm.sha256);
    expect(stored.digits, 8);
    expect(stored.period, 60);
    expect(stored.secret, 'JBSWY3DPEHPK3PXP');
  });

  test('import skips duplicate identities', () async {
    final state = await _initialize();
    addTearDown(state.dispose);
    await state.addAccount(_account('Example', 'alice', 'JBSWY3DPEHPK3PXP'));

    final added = await state.importAccounts([
      _account('Example', 'alice', 'JBSWY3DPEHPK3PXP'),
      _account('Other', 'bob', 'KRSXG5CTMVRXEZLU'),
    ]);

    expect(added, 1);
    expect(state.accounts, hasLength(2));
  });

  test('changing a sync password does not overwrite remote data', () async {
    final state = await _initialize();
    addTearDown(state.dispose);
    final account = _account('Example', 'alice', 'JBSWY3DPEHPK3PXP');
    await state.addAccount(account);
    expect(state.hasSyncPassword, isFalse);
    final before = state.accounts.single.updatedAt;

    await state.setSyncPassword('correct horse battery');
    expect(state.hasSyncPassword, isTrue);
    expect(state.accounts.single.updatedAt, before);
    expect(account.id, state.accounts.single.id);

    await state.setSyncPassword(null);
    expect(state.hasSyncPassword, isFalse);
  });

  test('HOTP counter advance persists', () async {
    final state = await _initialize();
    final account = TotpAccount.newAccount(
      issuer: 'Counter',
      accountName: 'c',
      secret: 'JBSWY3DPEHPK3PXP',
      type: TotpType.hotp,
    );
    await state.addAccount(account);
    final first = state.codeFor(account);
    final next = await state.advanceCounter(account);
    expect(account.counter, 1);
    expect(next, isNot(first));
    expect(state.secondsRemaining(account), 0);
    state.dispose();

    final reloaded = await _initialize();
    addTearDown(reloaded.dispose);
    expect(reloaded.accounts.single.counter, 1);
  });
}
