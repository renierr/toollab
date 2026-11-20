import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/area_warning.dart';
import '../models/weather_warning.dart';

/// DWD short-term warnings (thunderstorms, heavy rain) as area polygons.
class NowcastClient {
  NowcastClient._();

  static Uri url() => Uri.https(
    's3.eu-central-1.amazonaws.com',
    '/app-prod-static.warnwetter.de/v16/warnings_nowcast.json',
  );

  /// The file is stored gzip-compressed without a Content-Encoding header.
  static List<AreaWarning> parse(Uint8List bytes) {
    final raw = bytes.length > 2 && bytes[0] == 0x1F && bytes[1] == 0x8B
        ? const GZipDecoder().decodeBytes(bytes)
        : bytes;
    final json = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
    return [
      for (final w in json['warnings'] as List<dynamic>? ?? const [])
        if (w is Map<String, dynamic> && w['start'] != null)
          AreaWarning(WeatherWarning.fromJson(w, isNowcast: true), [
            for (final r in w['regions'] as List<dynamic>? ?? const [])
              if (r is Map<String, dynamic> && r['polygon'] is List)
                [for (final v in r['polygon'] as List) (v as num).toDouble()],
          ]),
    ];
  }
}
