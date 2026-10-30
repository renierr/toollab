import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/totp_auth/totp_crypto.dart';
import 'package:tool_lab/tools/totp_auth/totp_sync_delegate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('delegate is not ready without a sync password', () async {
    FlutterSecureStorage.setMockInitialValues({});
    expect(await TotpSyncDelegate().isReadyToSync(), isFalse);
  });

  test('delegate is ready once a password is stored', () async {
    FlutterSecureStorage.setMockInitialValues({
      TotpCrypto.syncPasswordKey: 'correct horse battery',
    });
    expect(await TotpSyncDelegate().isReadyToSync(), isTrue);
  });

  test('empty stored password counts as not configured', () async {
    FlutterSecureStorage.setMockInitialValues({TotpCrypto.syncPasswordKey: ''});
    expect(await TotpSyncDelegate().isReadyToSync(), isFalse);
  });
}
