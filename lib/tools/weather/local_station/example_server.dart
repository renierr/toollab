// Reference server for the ToolLab Local Weather Station API, version 1.
// Standalone: dart:io only, not imported by the app. See LOCAL_STATION_API.md.
//
//   dart lib/tools/weather/local_station/example_server.dart
//   dart lib/tools/weather/local_station/example_server.dart --port 9000 --sections observations
//   dart lib/tools/weather/local_station/example_server.dart --name Balkon --lat 52.52 --lon 13.40
//
// Plain `dart <file>`, not `dart run`: inside the project `dart run` first
// builds the native-asset hooks of every app dependency.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const String _api = 'toollab.weather-station';
const int _version = 1;
const List<String> _sections = ['observations', 'forecast', 'warnings', 'days'];

const List<String> _observationFields = [
  'temperature',
  'humidity',
  'dewPoint',
  'pressure',
  'windSpeed',
  'windDirection',
  'windGust',
  'precipitation1h',
  'precipitation24h',
  'cloudCover',
  'visibility',
  'sunshineMinutes',
  'condition',
];
const List<String> _forecastFields = [
  'temperature',
  'dewPoint',
  'pressure',
  'windSpeed',
  'windDirection',
  'windGust',
  'cloudCover',
  'precipitation',
  'precipitationProbability',
  'sunshineMinutes',
  'visibility',
  'condition',
];
const List<String> _dayFields = ['sunrise', 'sunset'];

class _Options {
  String bind = '0.0.0.0';
  int port = 8080;
  String id = 'example-01';
  String name = 'Example station';
  double lat = 50.1427;
  double lon = 8.5713;
  double elevation = 140;
  Set<String> sections = {..._sections};
}

Future<void> main(List<String> args) async {
  final options = _parse(args);
  if (options == null) {
    stderr.writeln(
      'Options: --bind <addr> --port <n> --id <id> --name <name> '
      '--lat <deg> --lon <deg> --elevation <m> '
      '--sections <${_sections.join(',')}> '
      '(must include observations or forecast)',
    );
    exitCode = 64;
    return;
  }
  final HttpServer server;
  try {
    server = await HttpServer.bind(options.bind, options.port);
  } on SocketException catch (e) {
    stderr.writeln(
      'Cannot listen on ${options.bind}:${options.port}: ${e.message}',
    );
    exitCode = 1;
    return;
  }
  await _printAddresses(server, options);
  await for (final request in server) {
    _handle(request, options);
  }
}

/// Lists the addresses to type into the app, since 0.0.0.0 is none of them.
Future<void> _printAddresses(HttpServer server, _Options o) async {
  final port = server.port;
  final bound = server.address;
  final anyAddress =
      bound.address == InternetAddress.anyIPv4.address ||
      bound.address == InternetAddress.anyIPv6.address;
  String url(String host) =>
      'http://${host.contains(':') ? '[$host]' : host}:$port';
  final lines = <String>[];
  if (anyAddress || bound.isLoopback) {
    lines.add('  This computer:     ${url('localhost')}');
  }
  if (anyAddress) {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    for (final i in interfaces) {
      for (final a in i.addresses) {
        lines.add('  Network (${i.name}): ${url(a.address)}');
      }
    }
    lines.add('  Android emulator:  ${url('10.0.2.2')}');
  } else if (!bound.isLoopback) {
    lines.add('  Network:           ${url(bound.address)}');
  }
  stdout
    ..writeln('Local weather station "${o.name}" is running on port $port')
    ..writeln('Sections: ${(o.sections.toList()..sort()).join(', ')}')
    ..writeln('Enter one of these addresses in the Weather tool')
    ..writeln('(Add place -> Local weather station):')
    ..writeAll(lines, '\n')
    ..writeln()
    ..writeln(
      'Manifest: ${url(anyAddress || bound.isLoopback ? 'localhost' : bound.address)}/weather-station.json',
    )
    ..writeln('Press Ctrl+C to stop.')
    ..writeln();
}

_Options? _parse(List<String> args) {
  final o = _Options();
  for (var i = 0; i < args.length; i++) {
    final key = args[i];
    if (i + 1 >= args.length) return null;
    final value = args[++i];
    switch (key) {
      case '--bind':
        o.bind = value;
      case '--port':
        o.port = int.tryParse(value) ?? -1;
      case '--id':
        o.id = value;
      case '--name':
        o.name = value;
      case '--lat':
        o.lat = double.tryParse(value) ?? double.nan;
      case '--lon':
        o.lon = double.tryParse(value) ?? double.nan;
      case '--elevation':
        o.elevation = double.tryParse(value) ?? 0;
      case '--sections':
        o.sections = {
          for (final s in value.split(','))
            if (s.trim().isNotEmpty) s.trim(),
        };
      default:
        return null;
    }
  }
  final valid =
      o.port > 0 &&
      o.lat.isFinite &&
      o.lon.isFinite &&
      o.sections.every(_sections.contains) &&
      (o.sections.contains('observations') || o.sections.contains('forecast'));
  return valid ? o : null;
}

void _handle(HttpRequest request, _Options o) {
  final now = DateTime.now();
  var path = request.uri.path;
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  final routes = <String, Object Function()>{
    '/': () => _manifest(o),
    '/weather-station.json': () => _manifest(o),
    if (o.sections.contains('observations'))
      '/observations.json': () => _observations(now),
    if (o.sections.contains('forecast')) '/forecast.json': () => _forecast(now),
    if (o.sections.contains('warnings')) '/warnings.json': () => _warnings(now),
    if (o.sections.contains('days')) '/days.json': () => _days(now, o.lat),
  };
  final build = routes[path];
  final response = request.response;
  if (request.method != 'GET' || build == null) {
    response.statusCode = build == null
        ? HttpStatus.notFound
        : HttpStatus.methodNotAllowed;
  } else {
    response
      ..headers.contentType = ContentType.json
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..write(const JsonEncoder.withIndent(' ').convert(build()));
  }
  stdout.writeln('${request.method} ${request.uri} ${response.statusCode}');
  response.close();
}

// --- fake weather model ------------------------------------------------------

/// Deterministic noise in [-1, 1] per hour, so repeated requests agree.
double _noise(int hourKey, int salt) =>
    math.Random(hourKey * 31 + salt).nextDouble() * 2 - 1;

double _round(double v, [int digits = 1]) {
  final f = math.pow(10, digits);
  return (v * f).round() / f;
}

/// A smooth daily cycle with a slow multi-day drift and some showers.
Map<String, Object> _weatherAt(DateTime t) {
  final hours = t.millisecondsSinceEpoch / 3600000;
  final key = hours.floor();
  final localHour = t.hour + t.minute / 60;
  final daily = math.sin((localHour - 9) / 24 * 2 * math.pi);
  final drift = 4 * math.sin(hours / 60);
  final temperature = 8 + drift + 5 * daily + 0.6 * _noise(key, 1);
  final cloud = (55 + 40 * math.sin(hours / 17) + 10 * _noise(key, 2)).clamp(
    0.0,
    100.0,
  );
  final wet = cloud > 80 && _noise(key, 3) > 0.1;
  final precipitation = wet
      ? _round(math.max(0, (cloud - 80) / 8 + _noise(key, 4)))
      : 0.0;
  final humidity = (75 - 15 * daily + cloud / 10 + (wet ? 10 : 0)).clamp(
    35.0,
    100.0,
  );
  final wind = math.max(0.0, 3 + 2 * math.sin(hours / 9) + _noise(key, 5));
  final isDay = localHour >= 8 && localHour < 16;
  final condition = switch (precipitation) {
    >= 4 => 'heavyRain',
    >= 1 => temperature > 1 ? 'rain' : 'snow',
    > 0 => temperature > 1 ? 'lightRain' : 'lightSnow',
    _ => switch (cloud) {
      < 15 => 'clear',
      < 35 => 'mostlyClear',
      < 65 => 'partlyCloudy',
      < 90 => 'cloudy',
      _ => 'overcast',
    },
  };
  return {
    'temperature': _round(temperature),
    'humidity': humidity.round(),
    'dewPoint': _round(temperature - (100 - humidity) / 5),
    'pressure': _round(1013 + 8 * math.sin(hours / 40) + 0.5 * _noise(key, 6)),
    'windSpeed': _round(wind),
    'windDirection': (220 + 60 * math.sin(hours / 30)).round() % 360,
    'windGust': _round(wind * 1.8 + _noise(key, 7).abs()),
    'cloudCover': cloud.round(),
    'precipitation': precipitation,
    'visibility': wet ? 4000 : 25000,
    'sunshineMinutes': isDay ? (60 * math.max(0, 1 - cloud / 90)).round() : 0,
    'condition': condition,
  };
}

/// ISO 8601 with the local offset, e.g. 2026-11-21T14:00:00+01:00.
String _iso(DateTime t) {
  final offset = t.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}'
      'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}'
      '$sign${two(minutes ~/ 60)}:${two(minutes % 60)}';
}

String _date(DateTime t) => _iso(t).substring(0, 10);

// --- sections ----------------------------------------------------------------

Map<String, Object> _manifest(_Options o) => {
  'api': _api,
  'version': _version,
  'station': {
    'id': o.id,
    'name': o.name,
    'latitude': o.lat,
    'longitude': o.lon,
    'elevation': o.elevation,
  },
  if (o.sections.contains('observations'))
    'observations': {
      'url': 'observations.json',
      'refreshSeconds': 300,
      'fields': _observationFields,
    },
  if (o.sections.contains('forecast'))
    'forecast': {
      'url': 'forecast.json',
      'refreshSeconds': 3600,
      'fields': _forecastFields,
    },
  if (o.sections.contains('warnings'))
    'warnings': {'url': 'warnings.json', 'refreshSeconds': 300},
  if (o.sections.contains('days'))
    'days': {'url': 'days.json', 'refreshSeconds': 21600, 'fields': _dayFields},
};

/// Latest 5-minute reading plus full-hour rows for the last 24 hours.
Map<String, Object> _observations(DateTime now) {
  final latest = DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute - now.minute % 5,
  );
  final fullHour = DateTime(now.year, now.month, now.day, now.hour);
  final times = <DateTime>{
    latest,
    for (var h = 0; h <= 24; h++) fullHour.subtract(Duration(hours: h)),
  };
  return {
    'rows': [
      for (final t in times)
        () {
          final w = _weatherAt(t);
          final lastDay = [
            for (var h = 0; h < 24; h++)
              _weatherAt(t.subtract(Duration(hours: h)))['precipitation']!
                  as double,
          ].fold<double>(0, (a, b) => a + b);
          return {
            'time': _iso(t),
            'temperature': w['temperature']!,
            'humidity': w['humidity']!,
            'dewPoint': w['dewPoint']!,
            'pressure': w['pressure']!,
            'windSpeed': w['windSpeed']!,
            'windDirection': w['windDirection']!,
            'windGust': w['windGust']!,
            'precipitation1h': w['precipitation']!,
            'precipitation24h': _round(lastDay),
            'cloudCover': w['cloudCover']!,
            'visibility': w['visibility']!,
            'sunshineMinutes': w['sunshineMinutes']!,
            'condition': w['condition']!,
          };
        }(),
    ],
  };
}

/// Hourly values from the next full hour, 10 days ahead.
Map<String, Object> _forecast(DateTime now) {
  final start = DateTime(now.year, now.month, now.day, now.hour + 1);
  return {
    'issued': _iso(start.subtract(const Duration(hours: 1))),
    'hours': [
      for (var h = 0; h < 240; h++)
        () {
          final t = start.add(Duration(hours: h));
          final w = _weatherAt(t);
          final cloud = w['cloudCover']! as int;
          return {
            'time': _iso(t),
            for (final field in _forecastFields)
              if (field != 'precipitationProbability') field: w[field]!,
            'precipitationProbability': cloud > 60
                ? (cloud * 0.8).round()
                : cloud ~/ 4,
          };
        }(),
    ],
  };
}

/// A frost notice for the coming night whenever it would be cold.
Map<String, Object> _warnings(DateTime now) {
  var night = DateTime(now.year, now.month, now.day, 22);
  if (now.hour >= 22) night = night.add(const Duration(days: 1));
  final morning = night.add(const Duration(hours: 11));
  final coldest = [
    for (var h = 0; h < 11; h++)
      _weatherAt(night.add(Duration(hours: h)))['temperature']! as double,
  ].reduce(math.min);
  if (coldest > 2) return {'warnings': <Object>[]};
  return {
    'warnings': [
      {
        'id': 'frost-${_date(night)}',
        'level': coldest < -2 ? 2 : 1,
        'start': _iso(night),
        'end': _iso(morning),
        'event': 'Frost',
        'headline': 'Frost expected tonight',
        'description': 'Temperatures down to ${coldest.round()} °C.',
        'instruction': 'Protect sensitive plants.',
      },
    ],
  };
}

/// Rough sun times from the day of year.
Map<String, Object> _days(DateTime now, double lat) => {
  'days': [
    for (var d = 0; d < 10; d++)
      () {
        final day = DateTime(now.year, now.month, now.day + d);
        final dayOfYear = day.difference(DateTime(day.year)).inDays + 1;
        final decl =
            23.44 *
            math.pi /
            180 *
            math.sin(2 * math.pi * (284 + dayOfYear) / 365);
        final cosH = (-math.tan(lat * math.pi / 180) * math.tan(decl)).clamp(
          -1.0,
          1.0,
        );
        final halfMinutes = (math.acos(cosH) * 180 / math.pi / 15 * 60).round();
        final noon = DateTime(day.year, day.month, day.day, 12, 15);
        return {
          'date': _date(day),
          'sunrise': _iso(noon.subtract(Duration(minutes: halfMinutes))),
          'sunset': _iso(noon.add(Duration(minutes: halfMinutes))),
        };
      }(),
  ],
};
