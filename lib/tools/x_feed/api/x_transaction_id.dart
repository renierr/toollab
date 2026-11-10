import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// Builds the `x-client-transaction-id` header x.com's web client signs its
/// API calls with. The key comes from the home page's verification meta tag,
/// the animation key from one of its hidden loading SVGs, and the byte indices
/// from the `ondemand.s` chunk.
class XTransactionId {
  static const String _keyword = 'obfiowerehiring';
  static const int _additionalRandomNumber = 3;
  static const int _epochOffsetSeconds = 1682924400;

  final List<int> _keyBytes;
  final String _animationKey;
  final math.Random _random;

  XTransactionId._(this._keyBytes, this._animationKey, this._random);

  static XTransactionId? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    final animation = json['animation'];
    if (key is! String || animation is! String) return null;
    try {
      return XTransactionId._(
        base64.decode(key),
        animation,
        math.Random.secure(),
      );
    } on FormatException {
      return null;
    }
  }

  Map<String, String> toJson() => {
    'key': base64.encode(_keyBytes),
    'animation': _animationKey,
  };

  static final RegExp _indicesPattern = RegExp(r'\(\w\[(\d{1,2})\],\s*16\)');
  static final RegExp _onDemandIndex = RegExp(
    r''',(\d+):["']ondemand\.s["']''',
  );
  static final RegExp _onDemandHashLegacy = RegExp(
    r'''["']ondemand\.s["']:\s*["'](\w+)["']''',
  );

  /// The ondemand chunk's URL as the home page names it, or null.
  static Uri? onDemandUrl(String homeHtml) {
    String? hash;
    final index = _onDemandIndex.firstMatch(homeHtml)?.group(1);
    if (index != null) {
      hash = RegExp(',$index:"([0-9a-f]+)"').firstMatch(homeHtml)?.group(1);
    }
    hash ??= _onDemandHashLegacy.firstMatch(homeHtml)?.group(1);
    if (hash == null) return null;
    return Uri.parse(
      'https://abs.twimg.com/responsive-web/client-web/ondemand.s.${hash}a.js',
    );
  }

  /// Null when either page no longer has the expected shape.
  static XTransactionId? create(
    String homeHtml,
    String onDemandJs, {
    math.Random? random,
  }) {
    final indices = _indicesPattern
        .allMatches(onDemandJs)
        .map((m) => int.parse(m.group(1)!))
        .toList();
    if (indices.length < 2) return null;

    final document = html_parser.parse(homeHtml);
    final key = document
        .querySelector("meta[name='twitter-site-verification']")
        ?.attributes['content'];
    if (key == null || key.isEmpty) return null;

    final List<int> keyBytes;
    try {
      keyBytes = base64.decode(base64.normalize(key));
    } on FormatException {
      return null;
    }
    if (keyBytes.length <= 5) return null;

    final frames = document
        .querySelectorAll('svg')
        .where((e) => (e.id).startsWith('loading-x-anim'))
        .toList();
    if (frames.length < 4) return null;

    try {
      final rows = _frameRows(frames[keyBytes[5] % 4]);
      final rowIndex = keyBytes[indices.first] % 16;
      if (rowIndex >= rows.length) return null;
      var frameTime = 1;
      for (final index in indices.skip(1)) {
        frameTime *= keyBytes[index] % 16;
      }
      frameTime = _jsRound(frameTime / 10) * 10;
      final animationKey = _animate(rows[rowIndex], frameTime / 4096);
      return XTransactionId._(
        keyBytes,
        animationKey,
        random ?? math.Random.secure(),
      );
    } catch (_) {
      return null;
    }
  }

  static List<List<int>> _frameRows(Element svg) {
    final group = svg.children.first;
    final d = group.children[1].attributes['d'] ?? '';
    return d
        .substring(9)
        .split('C')
        .map(
          (item) => item
              .replaceAll(RegExp(r'[^\d]+'), ' ')
              .trim()
              .split(' ')
              .where((s) => s.isNotEmpty)
              .map(int.parse)
              .toList(),
        )
        .toList();
  }

  String generate(String method, String path, {DateTime? now}) {
    final millis = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final time = ((millis - _epochOffsetSeconds * 1000) / 1000).floor();
    final timeBytes = [for (var i = 0; i < 4; i++) (time >> (i * 8)) & 0xff];
    final hash = sha256
        .convert(utf8.encode('$method!$path!$time$_keyword$_animationKey'))
        .bytes;
    final randomByte = _random.nextInt(256);
    final payload = [
      ..._keyBytes,
      ...timeBytes,
      ...hash.take(16),
      _additionalRandomNumber,
    ];
    final out = [randomByte, for (final b in payload) b ^ randomByte];
    return base64.encode(out).replaceAll('=', '');
  }

  static String _animate(List<int> frames, double targetTime) {
    final fromColor = [...frames.take(3).map((v) => v.toDouble()), 1.0];
    final toColor = [...frames.skip(3).take(3).map((v) => v.toDouble()), 1.0];
    final toRotation = _solve(frames[6].toDouble(), 60, 360, true);
    final curves = [
      for (var i = 7; i < frames.length; i++)
        _solve(frames[i].toDouble(), (i - 7).isOdd ? -1.0 : 0.0, 1, false),
    ];
    final value = _Cubic(curves).valueAt(targetTime);
    final color = [
      for (var i = 0; i < fromColor.length; i++)
        math.max(0.0, fromColor[i] * (1 - value) + toColor[i] * value),
    ];
    final rotation = toRotation * value;
    final radians = rotation * math.pi / 180;
    final matrix = [
      math.cos(radians),
      -math.sin(radians),
      math.sin(radians),
      math.cos(radians),
    ];

    final parts = <String>[
      for (final c in color.take(3)) _jsRound(c).toRadixString(16),
    ];
    for (final m in matrix) {
      var rounded = (m * 100).roundToDouble() / 100;
      if (rounded < 0) rounded = -rounded;
      final hex = _floatToHex(rounded);
      parts.add(
        hex.startsWith('.')
            ? '0$hex'.toLowerCase()
            : hex.isEmpty
            ? '0'
            : hex,
      );
    }
    parts.addAll(['0', '0']);
    return parts.join().replaceAll(RegExp(r'[.-]'), '');
  }

  static double _solve(double value, double min, double max, bool rounding) {
    final result = value * (max - min) / 255 + min;
    return rounding
        ? result.floorToDouble()
        : (result * 100).roundToDouble() / 100;
  }

  static int _jsRound(double value) => (value + 0.5).floor();

  static String _floatToHex(double x) {
    final result = <String>[];
    var quotient = x.truncate();
    var fraction = x - quotient;
    var rest = x;
    while (quotient > 0) {
      quotient = (rest / 16).truncate();
      final remainder = (rest - quotient * 16).truncate();
      result.insert(
        0,
        remainder > 9
            ? String.fromCharCode(remainder + 55)
            : remainder.toString(),
      );
      rest = quotient.toDouble();
    }
    if (fraction == 0) return result.join();
    result.add('.');
    while (fraction > 0) {
      fraction *= 16;
      final integer = fraction.truncate();
      fraction -= integer;
      result.add(
        integer > 9 ? String.fromCharCode(integer + 55) : integer.toString(),
      );
    }
    return result.join();
  }
}

class _Cubic {
  final List<double> curves;

  const _Cubic(this.curves);

  double valueAt(double time) {
    if (time <= 0) {
      var gradient = 0.0;
      if (curves[0] > 0) {
        gradient = curves[1] / curves[0];
      } else if (curves[1] == 0 && curves[2] > 0) {
        gradient = curves[3] / curves[2];
      }
      return gradient * time;
    }
    if (time >= 1) {
      var gradient = 0.0;
      if (curves[2] < 1) {
        gradient = (curves[3] - 1) / (curves[2] - 1);
      } else if (curves[2] == 1 && curves[0] < 1) {
        gradient = (curves[1] - 1) / (curves[0] - 1);
      }
      return 1 + gradient * (time - 1);
    }
    var start = 0.0;
    var end = 1.0;
    var mid = 0.0;
    for (var i = 0; i < 64 && start < end; i++) {
      mid = (start + end) / 2;
      final estimate = _calculate(curves[0], curves[2], mid);
      if ((time - estimate).abs() < 0.00001) {
        return _calculate(curves[1], curves[3], mid);
      }
      if (estimate < time) {
        start = mid;
      } else {
        end = mid;
      }
    }
    return _calculate(curves[1], curves[3], mid);
  }

  static double _calculate(double a, double b, double m) =>
      3 * a * (1 - m) * (1 - m) * m + 3 * b * (1 - m) * m * m + m * m * m;
}
