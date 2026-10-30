import 'dart:typed_data';

import 'package:crypto/crypto.dart';

enum TotpAlgorithm { sha1, sha256, sha512 }

enum TotpType { totp, hotp }

/// Components of an `otpauth://` setup link.
class TotpUriParts {
  final TotpType type;
  final String issuer;
  final String account;
  final String secret;
  final TotpAlgorithm algorithm;
  final int digits;
  final int period;
  final int counter;

  const TotpUriParts({
    required this.type,
    required this.issuer,
    required this.account,
    required this.secret,
    this.algorithm = TotpAlgorithm.sha1,
    this.digits = 6,
    this.period = 30,
    this.counter = 0,
  });
}

class Totp {
  Totp._();

  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Upper-cases and strips whitespace, dashes and Base32 padding.
  static String normalizeSecret(String input) {
    return input
        .replaceAll(RegExp(r'[\s\-]'), '')
        .replaceAll('=', '')
        .toUpperCase();
  }

  static bool isValidSecret(String input) {
    final cleaned = normalizeSecret(input);
    if (cleaned.length < 8) return false;
    return cleaned.split('').every(_alphabet.contains);
  }

  static Uint8List decodeBase32(String input) {
    final cleaned = normalizeSecret(input);
    final buffer = <int>[];
    int bits = 0;
    int value = 0;
    for (final ch in cleaned.split('')) {
      final idx = _alphabet.indexOf(ch);
      if (idx < 0) {
        throw FormatException('Invalid Base32 character: $ch');
      }
      value = (value << 5) | idx;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        buffer.add((value >> bits) & 0xff);
      }
    }
    if (buffer.isEmpty) {
      throw const FormatException('Empty Base32 secret');
    }
    return Uint8List.fromList(buffer);
  }

  static String encodeBase32(Uint8List data) {
    final out = StringBuffer();
    int bits = 0;
    int value = 0;
    for (final byte in data) {
      value = (value << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        out.write(_alphabet[(value >> bits) & 31]);
      }
    }
    if (bits > 0) {
      out.write(_alphabet[(value << (5 - bits)) & 31]);
    }
    return out.toString();
  }

  static int generate({
    required Uint8List secret,
    required int timeSeconds,
    int period = 30,
    int digits = 6,
    TotpAlgorithm algorithm = TotpAlgorithm.sha1,
  }) {
    return generateCounter(
      secret: secret,
      counter: timeSeconds ~/ period,
      digits: digits,
      algorithm: algorithm,
    );
  }

  static int generateCounter({
    required Uint8List secret,
    required int counter,
    int digits = 6,
    TotpAlgorithm algorithm = TotpAlgorithm.sha1,
  }) {
    final counterBytes = Uint8List(8);
    var c = counter;
    for (int i = 7; i >= 0; i--) {
      counterBytes[i] = c & 0xff;
      c >>= 8;
    }
    final mac = _hmac(algorithm, secret, counterBytes);
    final offset = mac.last & 0x0f;
    final code =
        ((mac[offset] & 0x7f) << 24) |
        ((mac[offset + 1] & 0xff) << 16) |
        ((mac[offset + 2] & 0xff) << 8) |
        (mac[offset + 3] & 0xff);
    return code % _pow10(digits);
  }

  static Uint8List _hmac(TotpAlgorithm algo, Uint8List key, Uint8List data) {
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

  /// Splits a code into readable groups without changing the digits.
  static String groupedCode(String code) {
    if (code.length == 6) return '${code.substring(0, 3)} ${code.substring(3)}';
    if (code.length == 7) return '${code.substring(0, 4)} ${code.substring(4)}';
    if (code.length == 8) return '${code.substring(0, 4)} ${code.substring(4)}';
    return code;
  }

  static TotpAlgorithm algorithmFromName(String? value) {
    switch (value?.toUpperCase()) {
      case 'SHA256':
        return TotpAlgorithm.sha256;
      case 'SHA512':
        return TotpAlgorithm.sha512;
      default:
        return TotpAlgorithm.sha1;
    }
  }

  static String algorithmName(TotpAlgorithm algorithm) {
    return switch (algorithm) {
      TotpAlgorithm.sha1 => 'SHA1',
      TotpAlgorithm.sha256 => 'SHA256',
      TotpAlgorithm.sha512 => 'SHA512',
    };
  }

  /// Parses an `otpauth://totp/...` or `otpauth://hotp/...` URI.
  static TotpUriParts? parseOtpAuthUri(String uri) {
    final cleaned = uri.trim();
    if (!cleaned.toLowerCase().startsWith('otpauth://')) return null;
    final u = Uri.tryParse(cleaned);
    if (u == null) return null;

    final kind = u.host.toLowerCase();
    if (kind != 'totp' && kind != 'hotp') return null;

    final secretRaw = u.queryParameters['secret'];
    final secret = secretRaw == null ? '' : normalizeSecret(secretRaw);
    if (!isValidSecret(secret)) return null;

    final rawLabel = u.pathSegments.isEmpty ? '' : u.pathSegments.join('/');
    final colon = rawLabel.indexOf(':');
    final labelIssuer = colon >= 0 ? rawLabel.substring(0, colon).trim() : '';
    final labelAccount = (colon >= 0 ? rawLabel.substring(colon + 1) : rawLabel)
        .trim();

    final issuer = (u.queryParameters['issuer'] ?? labelIssuer).trim();

    return TotpUriParts(
      type: kind == 'hotp' ? TotpType.hotp : TotpType.totp,
      issuer: issuer.isEmpty ? labelIssuer : issuer,
      account: labelAccount,
      secret: secret,
      algorithm: algorithmFromName(u.queryParameters['algorithm']),
      digits: _clampInt(u.queryParameters['digits'], 6, 6, 8),
      period: _clampInt(u.queryParameters['period'], 30, 1, 3600),
      counter: _clampInt(u.queryParameters['counter'], 0, 0, 0x7fffffff),
    );
  }

  static String buildOtpAuthUri({
    required TotpType type,
    required String issuer,
    required String account,
    required String secret,
    TotpAlgorithm algorithm = TotpAlgorithm.sha1,
    int digits = 6,
    int period = 30,
    int counter = 0,
  }) {
    final label = issuer.isEmpty ? account : '$issuer:$account';
    final params = <String, String>{
      'secret': normalizeSecret(secret),
      if (algorithm != TotpAlgorithm.sha1)
        'algorithm': algorithmName(algorithm),
      if (digits != 6) 'digits': '$digits',
      if (type == TotpType.hotp) ...{
        'counter': '$counter',
      } else if (period != 30)
        'period': '$period',
      if (issuer.isNotEmpty) 'issuer': issuer,
    };
    return Uri(
      scheme: 'otpauth',
      host: type == TotpType.hotp ? 'hotp' : 'totp',
      path: '/${Uri.encodeComponent(label)}',
      queryParameters: params,
    ).toString();
  }

  static int _clampInt(String? raw, int fallback, int min, int max) {
    final parsed = int.tryParse(raw ?? '');
    if (parsed == null) return fallback;
    return parsed.clamp(min, max);
  }
}
