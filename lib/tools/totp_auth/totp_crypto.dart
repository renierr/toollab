import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/pbkdf2_key.dart';

class TotpCrypto {
  /// Secure-storage key shared by the settings dialog and the sync delegate.
  static const syncPasswordKey = 'totp_sync_password';
  static const syncCheckRecordId = '__tool_lab_password_check__';

  static const int _defaultIterations = 100000;
  static int _iterations = _defaultIterations;

  /// Lowers the sync payload KDF for tests that only check the flow; null
  /// restores the real count.
  @visibleForTesting
  static void setIterationsForTesting(int? iterations) =>
      _iterations = iterations ?? _defaultIterations;
  static final _aes = AesGcm.with256bits();

  /// 2FAS derives its AES key with PBKDF2-SHA256 and 10,000 iterations.
  static const _twoFasIterations = 10000;

  static Future<String> encrypt(String plaintext, String password) async {
    final salt = _randomBytes(16);
    final secretKey = await derivePbkdf2Key(
      iterations: _iterations,
      password: password,
      salt: salt,
    );
    final nonce = _aes.newNonce();
    final box = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );
    final out = <int>[...salt, ...nonce, ...box.cipherText, ...box.mac.bytes];
    return base64Encode(out);
  }

  static Future<String> decrypt(String payload, String password) async {
    final bytes = base64Decode(payload);
    final salt = bytes.sublist(0, 16);
    final nonce = bytes.sublist(16, 28);
    final macBytes = bytes.sublist(bytes.length - 16);
    final cipherText = bytes.sublist(28, bytes.length - 16);
    final secretKey = await derivePbkdf2Key(
      iterations: _iterations,
      password: password,
      salt: salt,
    );
    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
    final clear = await _aes.decrypt(box, secretKey: secretKey);
    return utf8.decode(clear);
  }

  /// Decrypts a 2FAS `servicesEncrypted` value:
  /// `base64(cipher+tag):base64(salt):base64(nonce)`.
  static Future<String> decryptTwoFas(String payload, String password) async {
    final parts = payload.split(':');
    if (parts.length != 3) {
      throw const FormatException('Malformed 2FAS payload');
    }
    final cipherWithTag = base64Decode(parts[0]);
    final salt = base64Decode(parts[1]);
    final nonce = base64Decode(parts[2]);
    if (cipherWithTag.length <= 16) {
      throw const FormatException('Malformed 2FAS ciphertext');
    }
    final secretKey = await derivePbkdf2Key(
      iterations: _twoFasIterations,
      password: password,
      salt: salt,
    );
    final box = SecretBox(
      cipherWithTag.sublist(0, cipherWithTag.length - 16),
      nonce: nonce,
      mac: Mac(cipherWithTag.sublist(cipherWithTag.length - 16)),
    );
    final clear = await _aes.decrypt(box, secretKey: secretKey);
    return utf8.decode(clear);
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }
}
