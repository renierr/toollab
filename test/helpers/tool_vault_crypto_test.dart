import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/helpers/tool_vault_crypto.dart';

void main() {
  test(
    'password wraps a random key and records authenticate their context',
    () async {
      final key = await ToolVaultCrypto.newDataKey();
      final wrapped = await ToolVaultCrypto.wrapKey(key, 'a strong passphrase');
      final unlocked = await ToolVaultCrypto.unwrapKey(
        wrapped,
        'a strong passphrase',
      );
      final encrypted = await ToolVaultCrypto.encrypt(
        'private account',
        key,
        context: 'tool/record',
      );
      expect(encrypted, isNot(contains('private account')));
      expect(
        await ToolVaultCrypto.decrypt(
          encrypted,
          unlocked,
          context: 'tool/record',
        ),
        'private account',
      );
      await expectLater(
        ToolVaultCrypto.decrypt(encrypted, unlocked, context: 'tool/other'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await expectLater(
        ToolVaultCrypto.unwrapKey(wrapped, 'wrong password'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    },
  );

  test('wrapping and record encryption use fresh randomness', () async {
    final key = await ToolVaultCrypto.newDataKey();
    expect(
      await ToolVaultCrypto.wrapKey(key, 'password'),
      isNot(await ToolVaultCrypto.wrapKey(key, 'password')),
    );
    expect(
      await ToolVaultCrypto.encrypt('same', key, context: 'id'),
      isNot(await ToolVaultCrypto.encrypt('same', key, context: 'id')),
    );
  });

  test('invalid envelopes and tampered data fail', () async {
    final key = await ToolVaultCrypto.newDataKey();
    final wrapped = await ToolVaultCrypto.wrapKey(key, 'password');
    final envelope = jsonDecode(wrapped) as Map<String, dynamic>;
    envelope['version'] = 99;
    await expectLater(
      ToolVaultCrypto.unwrapKey(jsonEncode(envelope), 'password'),
      throwsFormatException,
    );
    final encrypted = await ToolVaultCrypto.encrypt(
      'secret',
      key,
      context: 'id',
    );
    final bytes = base64Decode(encrypted);
    bytes[12] ^= 1;
    await expectLater(
      ToolVaultCrypto.decrypt(base64Encode(bytes), key, context: 'id'),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
}
