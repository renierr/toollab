import 'dart:typed_data';

import 'package:crypto/crypto.dart';

enum TotpAlgorithm { sha1, sha256, sha512 }

class Totp {
  static Uint8List decodeBase32(String input) {
    final cleaned = input.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final buffer = <int>[];
    int bits = 0;
    int value = 0;
    for (final ch in cleaned.split('')) {
      if (ch == '=') continue;
      final idx = alphabet.indexOf(ch);
      if (idx < 0) continue;
      value = (value << 5) | idx;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        buffer.add((value >> bits) & 0xff);
      }
    }
    return Uint8List.fromList(buffer);
  }

  static String encodeBase32(Uint8List data) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final out = StringBuffer();
    int bits = 0;
    int value = 0;
    for (final byte in data) {
      value = (value << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        out.write(alphabet[(value >> bits) & 31]);
      }
    }
    if (bits > 0) {
      out.write(alphabet[(value << (5 - bits)) & 31]);
    }
    // pad
    while (out.length % 8 != 0) {
      out.write('=');
    }    return out.toString();
  }

  static int generate({
    required Uint8List secret,
    required int timeSeconds,
    int period = 30,
    int digits = 6,
    TotpAlgorithm algorithm = TotpAlgorithm.sha1,
  }) {
    final counter = timeSeconds ~/ period;
    final counterBytes = Uint8List(8);
    var c = counter;
    for (int i = 7; i >= 0; i--) {
      counterBytes[i] = c & 0xff;
      c >>= 8;
    }
    final mac = _hmac(algorithm, secret, counterBytes);
    final offset = mac.last & 0x0f;
    final code = ((mac[offset] & 0x7f) << 24) |
        ((mac[offset + 1] & 0xff) << 16) |
        ((mac[offset + 2] & 0xff) << 8) |
        (mac[offset + 3] & 0xff);
    final mod = _pow10(digits);
    return code % mod;
  }

  static Uint8List _hmac(
    TotpAlgorithm algo,
    Uint8List key,
    Uint8List data,
  ) {
    final h = switch (algo) {
      TotpAlgorithm.sha1 => sha1,
      TotpAlgorithm.sha256 => sha256,
      TotpAlgorithm.sha512 => sha512,
    };
    return Uint8List.fromList(Hmac(h, key).convert(data).bytes);
  }

  static int _pow10(int n) {
    int r = 1;
    for (int i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  static String formatCode(int code, int digits) {
    return code.toString().padLeft(digits, '0');
  }

  /// Parses an otpauth:// URI into components.
  static Map<String, String>? parseOtpAuthUri(String uri) {
    final u = Uri.tryParse(uri.trim());
    if (u == null || u.scheme != 'otpauth') return null;
    final label = u.pathSegments.isNotEmpty
        ? Uri.decodeComponent(u.pathSegments.last)
        : '';
    final issuer = u.queryParameters['issuer'] ?? (label.contains(':') ? label.split(':').first : '');
    final account = label.contains(':') ? label.split(':').last.trim() : label;
    final secret = u.queryParameters['secret'];
    if (secret == null || secret.isEmpty) return null;
    return {
      'issuer': issuer,
      'account': account,
      'secret': secret,
      'algorithm': (u.queryParameters['algorithm'] ?? 'SHA1').toUpperCase(),
      'digits': u.queryParameters['digits'] ?? '6',
      'period': u.queryParameters['period'] ?? '30',
    };
  }
}
