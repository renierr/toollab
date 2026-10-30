import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class ToolVaultCleanupPending implements Exception {}

class ToolVaultCrypto {
  ToolVaultCrypto._();

  static const int _iterations = 600000;
  static final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  );
  static final _cipher = AesGcm.with256bits();
  static final _random = Random.secure();

  static List<int> _randomBytes(int length) =>
      List.generate(length, (_) => _random.nextInt(256));

  static Future<SecretKey> newDataKey() async => SecretKey(_randomBytes(32));

  static Future<String> wrapKey(SecretKey dataKey, String password) async {
    if (password.isEmpty) throw ArgumentError('Password must not be empty');
    final salt = _randomBytes(16);
    final key = await _kdf.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final nonce = _cipher.newNonce();
    final box = await _cipher.encrypt(
      await dataKey.extractBytes(),
      secretKey: key,
      nonce: nonce,
      aad: utf8.encode('tool-lab-vault-key-v1'),
    );
    return jsonEncode({
      'version': 1,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(box.cipherText),
      'tag': base64Encode(box.mac.bytes),
    });
  }

  static Future<SecretKey> unwrapKey(String envelope, String password) async {
    final data = jsonDecode(envelope) as Map<String, dynamic>;
    if (data['version'] != 1) {
      throw const FormatException('Unsupported vault version');
    }
    final salt = base64Decode(data['salt'] as String);
    final nonce = base64Decode(data['nonce'] as String);
    final ciphertext = base64Decode(data['ciphertext'] as String);
    final tag = base64Decode(data['tag'] as String);
    if (salt.length != 16 ||
        nonce.length != 12 ||
        ciphertext.length != 32 ||
        tag.length != 16) {
      throw const FormatException('Invalid vault key envelope');
    }
    final key = await _kdf.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final bytes = await _cipher.decrypt(
      SecretBox(ciphertext, nonce: nonce, mac: Mac(tag)),
      secretKey: key,
      aad: utf8.encode('tool-lab-vault-key-v1'),
    );
    return SecretKey(bytes);
  }

  static Future<String> encrypt(
    String plaintext,
    SecretKey dataKey, {
    required String context,
  }) async {
    final nonce = _cipher.newNonce();
    final box = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: dataKey,
      nonce: nonce,
      aad: utf8.encode(context),
    );
    return base64Encode([...nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  static Future<String> decrypt(
    String payload,
    SecretKey dataKey, {
    required String context,
  }) async {
    final bytes = base64Decode(payload);
    if (bytes.length < 28) throw const FormatException('Invalid vault payload');
    final clear = await _cipher.decrypt(
      SecretBox(
        bytes.sublist(12, bytes.length - 16),
        nonce: bytes.sublist(0, 12),
        mac: Mac(bytes.sublist(bytes.length - 16)),
      ),
      secretKey: dataKey,
      aad: utf8.encode(context),
    );
    return utf8.decode(clear);
  }
}
