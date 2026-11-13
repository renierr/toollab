import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/chat_ai/deepseek/deepseek_pow.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

DeepSeekPowChallenge _challenge(String challenge, String salt, int expireAt) =>
    DeepSeekPowChallenge(
      algorithm: 'DeepSeekHashV1',
      challenge: challenge,
      salt: salt,
      signature: 'sig',
      difficulty: 144000,
      expireAt: expireAt,
      targetPath: '/api/v0/chat/completion',
    );

void main() {
  test('hashes like the web client', () {
    expect(
      _hex(
        DeepSeekPow.hash(
          utf8.encode('310749ae199b19d06d3f_1794607629725_58428'),
        ),
      ),
      '6cec8eefffff8d78622b75470fd0f5704e895a2d7b3a750276a6a76f0d4ea44b',
    );
  });

  test('solves recorded challenges', () {
    expect(
      DeepSeekPow.solve(
        _challenge(
          '6cec8eefffff8d78622b75470fd0f5704e895a2d7b3a750276a6a76f0d4ea44b',
          '310749ae199b19d06d3f',
          1794607629725,
        ),
      ),
      58428,
    );
    expect(
      DeepSeekPow.solve(
        _challenge(
          'c1a576cd1b913ea436c1b218d3dff5e27c8eac5dbd815f94a319ce8b49392262',
          '56210c014d93dde9fd71',
          1794607639508,
        ),
      ),
      38113,
    );
  });

  test('rejects unknown algorithms', () {
    final challenge = DeepSeekPowChallenge.fromJson({
      'algorithm': 'Other',
      'challenge': '00' * 32,
      'difficulty': 10,
    });
    expect(DeepSeekPow.solve(challenge), isNull);
  });

  test('encodes the response header', () {
    final header = _challenge('ab', 'salt', 1).header(7);
    final decoded = jsonDecode(utf8.decode(base64.decode(header))) as Map;
    expect(decoded['answer'], 7);
    expect(decoded['target_path'], '/api/v0/chat/completion');
    expect(decoded.keys, [
      'algorithm',
      'challenge',
      'salt',
      'answer',
      'signature',
      'target_path',
    ]);
  });
}
