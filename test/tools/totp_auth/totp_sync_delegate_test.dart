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

  test('a stored password cannot enable sync while locked', () async {
    FlutterSecureStorage.setMockInitialValues({
      TotpCrypto.syncPasswordKey: 'correct horse battery',
    });
    expect(await TotpSyncDelegate().isReadyToSync(), isFalse);
  });

  test('empty stored password counts as not configured', () async {
    FlutterSecureStorage.setMockInitialValues({TotpCrypto.syncPasswordKey: ''});
    expect(await TotpSyncDelegate().isReadyToSync(), isFalse);
  });
}
