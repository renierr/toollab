import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

/// A proof-of-work challenge from `create_pow_challenge`.
class DeepSeekPowChallenge {
  final String algorithm;
  final String challenge;
  final String salt;
  final String signature;
  final int difficulty;
  final int expireAt;
  final String targetPath;

  const DeepSeekPowChallenge({
    required this.algorithm,
    required this.challenge,
    required this.salt,
    required this.signature,
    required this.difficulty,
    required this.expireAt,
    required this.targetPath,
  });

  factory DeepSeekPowChallenge.fromJson(Map<String, dynamic> json) =>
      DeepSeekPowChallenge(
        algorithm: json['algorithm'] as String? ?? '',
        challenge: json['challenge'] as String? ?? '',
        salt: json['salt'] as String? ?? '',
        signature: json['signature'] as String? ?? '',
        difficulty: (json['difficulty'] as num?)?.toInt() ?? 0,
        expireAt: (json['expire_at'] as num?)?.toInt() ?? 0,
        targetPath: json['target_path'] as String? ?? '',
      );

  /// The `x-ds-pow-response` header value for [answer].
  String header(int answer) => base64.encode(
    utf8.encode(
      jsonEncode({
        'algorithm': algorithm,
        'challenge': challenge,
        'salt': salt,
        'answer': answer,
        'signature': signature,
        'target_path': targetPath,
      }),
    ),
  );
}

/// DeepSeekHashV1: SHA3-256 without the first Keccak round.
class DeepSeekPow {
  DeepSeekPow._();

  static const String algorithm = 'DeepSeekHashV1';
  static const int _rate = 136;

  static const List<int> _roundConstants = [
    0x0000000000000001,
    0x0000000000008082,
    0x800000000000808a,
    0x8000000080008000,
    0x000000000000808b,
    0x0000000080000001,
    0x8000000080008081,
    0x8000000000008009,
    0x000000000000008a,
    0x0000000000000088,
    0x0000000080008009,
    0x000000008000000a,
    0x000000008000808b,
    0x800000000000008b,
    0x8000000000008089,
    0x8000000000008003,
    0x8000000000008002,
    0x8000000000000080,
    0x000000000000800a,
    0x800000008000000a,
    0x8000000080008081,
    0x8000000000008080,
    0x0000000080000001,
    0x8000000080008008,
  ];

  static const List<int> _rotations = [
    0, 1, 62, 28, 27, 36, 44, 6, 55, 20, 3, 10, 43, 25, 39, 41, 45, 15, //
    21, 8, 18, 2, 61, 56, 14,
  ];

  /// Lane index each lane moves to in the pi step.
  static final List<int> _piTarget = [
    for (var i = 0; i < 25; i++)
      (i ~/ 5) + 5 * ((2 * (i % 5) + 3 * (i ~/ 5)) % 5),
  ];

  static int _rotl(int x, int n) => n == 0 ? x : (x << n) | (x >>> (64 - n));

  static void _permute(List<int> a, List<int> b, List<int> c) {
    for (var round = 1; round < 24; round++) {
      for (var x = 0; x < 5; x++) {
        c[x] = a[x] ^ a[x + 5] ^ a[x + 10] ^ a[x + 15] ^ a[x + 20];
      }
      for (var x = 0; x < 5; x++) {
        final d = c[(x + 4) % 5] ^ _rotl(c[(x + 1) % 5], 1);
        for (var y = 0; y < 25; y += 5) {
          a[x + y] ^= d;
        }
      }
      for (var i = 0; i < 25; i++) {
        b[_piTarget[i]] = _rotl(a[i], _rotations[i]);
      }
      for (var y = 0; y < 25; y += 5) {
        for (var x = 0; x < 5; x++) {
          a[x + y] = b[x + y] ^ (~b[(x + 1) % 5 + y] & b[(x + 2) % 5 + y]);
        }
      }
      a[0] ^= _roundConstants[round];
    }
  }

  static Uint8List hash(List<int> message) {
    final padded = Uint8List((message.length ~/ _rate + 1) * _rate)
      ..setAll(0, message);
    padded[message.length] ^= 0x06;
    padded[padded.length - 1] ^= 0x80;
    final data = ByteData.sublistView(padded);
    final a = List<int>.filled(25, 0);
    final b = List<int>.filled(25, 0);
    final c = List<int>.filled(5, 0);
    for (var offset = 0; offset < padded.length; offset += _rate) {
      for (var i = 0; i < _rate ~/ 8; i++) {
        a[i] ^= data.getUint64(offset + i * 8, Endian.little);
      }
      _permute(a, b, c);
    }
    final out = ByteData(32);
    for (var i = 0; i < 4; i++) {
      out.setUint64(i * 8, a[i], Endian.little);
    }
    return out.buffer.asUint8List();
  }

  /// The answer whose hash matches the challenge, or null if none below the
  /// difficulty does.
  static int? solve(DeepSeekPowChallenge challenge) {
    if (challenge.algorithm != algorithm) return null;
    final target = _hexBytes(challenge.challenge);
    if (target == null) return null;
    final prefix = utf8.encode('${challenge.salt}_${challenge.expireAt}_');
    for (var answer = 0; answer < challenge.difficulty; answer++) {
      final digest = hash([...prefix, ...ascii.encode('$answer')]);
      if (_equals(digest, target)) return answer;
    }
    return null;
  }

  static Future<int?> solveInBackground(DeepSeekPowChallenge challenge) =>
      Isolate.run(() => solve(challenge));

  static Uint8List? _hexBytes(String hex) {
    if (hex.length != 64) return null;
    final out = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      final byte = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      if (byte == null) return null;
      out[i] = byte;
    }
    return out;
  }

  static bool _equals(Uint8List a, Uint8List b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
