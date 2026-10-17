import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class TotpCrypto {
  static final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 100000,
    bits: 256,
  );
  static final _aes = AesGcm.with256bits();

  static Future<String> encrypt(String plaintext, String password) async {
    final salt = _randomBytes(16);
    final secretKey = await _pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final nonce = _aes.newNonce();
    final box = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );
    final out = <int>[
      ...salt,
      ...nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ];
    return base64Encode(out);
  }

  static Future<String> decrypt(String payload, String password) async {
    final bytes = base64Decode(payload);
    final salt = bytes.sublist(0, 16);
    final nonce = bytes.sublist(16, 28);
    final macBytes = bytes.sublist(bytes.length - 16);
    final cipherText = bytes.sublist(28, bytes.length - 16);
    final secretKey = await _pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
    final clear = await _aes.decrypt(box, secretKey: secretKey);
    return utf8.decode(clear);
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }
}
