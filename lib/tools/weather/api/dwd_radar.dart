import 'dart:math' as math;
import 'dart:ui' show Color, Rect;

import 'package:xml/xml.dart';

import 'weather_http.dart';

/// Web Mercator (EPSG:3857) helpers; the DWD WMS renders natively in it.
class Mercator {
  Mercator._();

  static const double _r = 6378137.0;

  static double x(double lon) => _r * lon * math.pi / 180;

  static double y(double lat) =>
      _r * math.log(math.tan(math.pi / 4 + lat * math.pi / 360));

  static double lon(double x) => x / _r * 180 / math.pi;

  static double lat(double y) =>
      (2 * math.atan(math.exp(y / _r)) - math.pi / 2) * 180 / math.pi;

  /// Rough radar coverage of the DWD composite.
  static final Rect coverage = Rect.fromLTRB(x(1.5), y(45.5), x(18.5), y(56.2));
}

/// Available radar frames: observed up to [latestObserved], nowcast after it.
class RadarTimeline {
  const RadarTimeline({required this.times, required this.latestObserved});

  final List<DateTime> times;
  final DateTime latestObserved;

  bool isForecast(DateTime t) => t.isAfter(latestObserved);

  /// Index of the newest observed frame.
  int get nowIndex {
    var index = 0;
    for (var i = 0; i < times.length; i++) {
      if (!times[i].isAfter(latestObserved)) index = i;
    }
    return index;
  }

  /// Keeps [past] before the latest observation plus every nowcast frame.
  static RadarTimeline parseCapabilities(
    String xml, {
    Duration past = const Duration(hours: 2),
  }) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(xml);
    } on XmlException {
      throw const WeatherException(WeatherError.invalidData);
    }
    String? dimension(String name) {
      for (final d in doc.findAllElements('Dimension')) {
        if (d.getAttribute('name')?.toLowerCase() == name.toLowerCase()) {
          return d.innerText.trim();
        }
      }
      return null;
    }

    String? defaultOf(String name) {
      for (final d in doc.findAllElements('Dimension')) {
        if (d.getAttribute('name')?.toLowerCase() == name.toLowerCase()) {
          return d.getAttribute('default');
        }
      }
      return null;
    }

    final range = dimension('time')?.split('/');
    if (range == null || range.length != 3) {
      throw const WeatherException(WeatherError.invalidData);
    }
    final end = DateTime.parse(range[1]);
    final step = _parseDuration(range[2]);
    final reference = DateTime.tryParse(defaultOf('REFERENCE_TIME') ?? '');
    final latest = reference ?? end.subtract(const Duration(hours: 2));
    final start = latest.subtract(past);
    final times = <DateTime>[];
    for (var t = end; !t.isBefore(start); t = t.subtract(step)) {
      times.add(t);
    }
    return RadarTimeline(
      times: times.reversed.toList(),
      latestObserved: latest,
    );
  }

  static Duration _parseDuration(String iso) {
    final m = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?').firstMatch(iso);
    final hours = int.tryParse(m?.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(m?.group(2) ?? '') ?? 5;
    final d = Duration(hours: hours, minutes: minutes);
    return d == Duration.zero ? const Duration(minutes: 5) : d;
  }
}

/// PNG8 keeps transparency and the exact legend colours at about half the
/// size of full PNG; JPEG suits only the opaque satellite base.
enum WmsFormat {
  png8('image/png8'),
  jpeg('image/jpeg');

  const WmsFormat(this.mime);
  final String mime;
}

class DwdRadarClient {
  DwdRadarClient._();

  static const String radarLayer = 'dwd:Niederschlagsradar';
  static const String satelliteLayer = 'dwd:bluemarble';
  static const String lightningLayer = 'dwd:Blitzdichte';
  static const String warningsLayer = 'dwd:Warnungen_Landkreise';

  static Uri capabilitiesUrl() => Uri.https(
    'maps.dwd.de',
    '/geoserver/dwd/Niederschlagsradar/wms',
    {'service': 'WMS', 'version': '1.3.0', 'request': 'GetCapabilities'},
  );

  static Uri mapUrl({
    required List<String> layers,
    List<String>? styles,
    required Rect bbox,
    required int width,
    required int height,
    DateTime? time,
    WmsFormat format = WmsFormat.png8,
  }) => Uri.https('maps.dwd.de', '/geoserver/dwd/wms', {
    'service': 'WMS',
    'version': '1.3.0',
    'request': 'GetMap',
    'layers': layers.join(','),
    'styles': (styles ?? List.filled(layers.length, '')).join(','),
    'crs': 'EPSG:3857',
    'bbox': [
      bbox.left,
      bbox.top,
      bbox.right,
      bbox.bottom,
    ].map((v) => v.toStringAsFixed(0)).join(','),
    'width': '$width',
    'height': '$height',
    'format': format.mime,
    'transparent': format == WmsFormat.jpeg ? 'false' : 'true',
    if (time != null) 'time': time.toUtc().toIso8601String(),
  });

  /// Borders and rivers drawn over the satellite base.
  static Uri overlayUrl({
    required Rect bbox,
    required int width,
    required int height,
  }) => mapUrl(
    layers: const ['dwd:Laender', 'dwd:Gewaesser'],
    styles: const ['Laender_grau', ''],
    bbox: bbox,
    width: width,
    height: height,
  );
}

/// The colour classes of the DWD radar legend with their mm/h range.
class RadarPalette {
  RadarPalette._();

  static const List<(Color, double)> classes = [
    (Color(0xFF33FFFF), 0.1),
    (Color(0xFF1ACC9A), 0.2),
    (Color(0xFF019934), 0.4),
    (Color(0xFF4DB31B), 1.0),
    (Color(0xFF99CC01), 2.0),
    (Color(0xFFCCE601), 3.0),
    (Color(0xFFFFFF01), 5.0),
    (Color(0xFFFFC401), 7.5),
    (Color(0xFFFF8901), 10),
    (Color(0xFFFF4501), 15),
    (Color(0xFFFE0000), 30),
    (Color(0xFFE5004C), 45),
    (Color(0xFFCC0098), 75),
    (Color(0xFF6600CB), 100),
    (Color(0xFF0000FE), 150),
  ];

  /// Lower bound in mm/h of the class nearest to an RGBA pixel, or null when
  /// the pixel is transparent or not a legend colour.
  static double? intensity(int r, int g, int b, int a) {
    if (a < 128) return null;
    var best = double.infinity;
    double? value;
    for (final (color, mm) in classes) {
      final dr = (color.r * 255).round() - r;
      final dg = (color.g * 255).round() - g;
      final db = (color.b * 255).round() - b;
      final d = (dr * dr + dg * dg + db * db).toDouble();
      if (d < best) {
        best = d;
        value = mm;
      }
    }
    return best <= 40 * 40 ? value : null;
  }
}
