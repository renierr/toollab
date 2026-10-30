import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/totp_auth/totp.dart';
import 'package:tool_lab/tools/totp_auth/totp_account.dart';
import 'package:tool_lab/tools/totp_auth/totp_auth_state.dart';
import 'package:tool_lab/tools/totp_auth/totp_crypto.dart';

Future<TotpAuthState> _initialize() async {
  final state = TotpAuthState();
  await state.ready;
  if (state.lockController.configured) {
    expect(await state.unlockVault('correct horse battery'), isTrue);
  } else {
    await state.setupVault('correct horse battery');
  }
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

  test('locking clears accounts and disables sync until unlocked', () async {
    final state = await _initialize();
    addTearDown(state.dispose);
    final account = _account('Example', 'alice', 'JBSWY3DPEHPK3PXP');
    await state.addAccount(account);
    expect(state.hasSyncPassword, isTrue);
    state.lockController.lock();
    expect(state.hasSyncPassword, isFalse);
    expect(state.accounts, isEmpty);
    expect(await state.unlockVault('correct horse battery'), isTrue);
    expect(state.accounts.single.id, account.id);
  });

  test('an unlock interrupted by locking cannot reopen the vault', () async {
    final state = await _initialize();
    addTearDown(state.dispose);
    state.lockController.lock();
    final unlock = state.unlockVault('correct horse battery');
    state.lockController.lock();
    expect(await unlock, isFalse);
    expect(state.hasSyncPassword, isFalse);
  });

  test(
    'automatic unlock is only started explicitly when the tool is open',
    () async {
      final first = await _initialize();
      await first.lockController.setAutomatic(true);
      first.dispose();
      final second = TotpAuthState();
      await second.ready;
      addTearDown(second.dispose);
      expect(second.hasSyncPassword, isFalse);
      await second.unlockAutomatically();
      expect(second.hasSyncPassword, isTrue);
    },
  );

  test('five wrong passwords allow confirmed local reset', () async {
    final state = await _initialize();
    addTearDown(state.dispose);
    await state.addAccount(_account('Example', 'alice', 'JBSWY3DPEHPK3PXP'));
    state.lockController.lock();
    await expectLater(state.resetVault(), throwsStateError);
    for (var i = 0; i < 5; i++) {
      expect(await state.unlockVault('wrong password'), isFalse);
    }
    expect(state.lockController.canReset, isTrue);
    await state.resetVault();
    expect(state.lockController.configured, isFalse);
    await state.setupVault('new password');
    expect(state.accounts, isEmpty);
  });

  test('forgotten previous sync password permits local reset', () async {
    FlutterSecureStorage.setMockInitialValues({
      TotpCrypto.syncPasswordKey: 'old password',
    });
    final state = TotpAuthState();
    await state.ready;
    addTearDown(state.dispose);
    for (var i = 0; i < 5; i++) {
      await expectLater(
        state.setupVault('different password'),
        throwsException,
      );
    }
    expect(state.lockController.canReset, isTrue);
    await state.resetVault();
    await state.setupVault('different password');
    expect(state.accounts, isEmpty);
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
