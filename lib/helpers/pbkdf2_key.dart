import 'dart:io';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';

/// PBKDF2-HMAC-SHA256, 256 bits. Desktop has no native PBKDF2, so it runs off
/// the UI isolate; Android keeps cryptography_flutter's main-isolate one.
Future<SecretKey> derivePbkdf2Key({
  required int iterations,
  required String password,
  required List<int> salt,
}) async {
  Future<SecretKey> derive() => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  ).deriveKeyFromPassword(password: password, nonce: salt);

  if (Platform.isLinux || Platform.isWindows) {
    final bytes = await Isolate.run(
      () async => (await derive()).extractBytes(),
    );
    return SecretKey(bytes);
  }
  return derive();
}
