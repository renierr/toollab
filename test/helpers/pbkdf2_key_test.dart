import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/helpers/pbkdf2_key.dart';

void main() {
  test('native derivation matches pure Dart PBKDF2', () async {
    final salt = List<int>.generate(16, (i) => i * 7);
    for (final password in ['correct horse', 'Pässwörd-ß€😀', '']) {
      final expected = await Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 1000,
        bits: 256,
      ).deriveKeyFromPassword(password: password, nonce: salt);
      final actual = await derivePbkdf2Key(
        iterations: 1000,
        password: password,
        salt: salt,
      );
      expect(await actual.extractBytes(), await expected.extractBytes());
    }
  });
}
