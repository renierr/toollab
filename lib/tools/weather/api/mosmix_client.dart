import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../models/hourly_forecast.dart';
import '../models/mosmix_forecast.dart';
import 'weather_http.dart';

class MosmixClient {
  const MosmixClient();

  static Uri url(String stationId) => Uri.https(
    'opendata.dwd.de',
    '/weather/local_forecasts/mos/MOSMIX_L/single_stations/$stationId/kml/MOSMIX_L_LATEST_$stationId.kmz',
  );

  Future<MosmixForecast> fetch(String stationId) async =>
      parseKmz(await WeatherHttp.getBytes(url(stationId)), stationId);

  static MosmixForecast parseKmz(Uint8List bytes, String stationId) {
    final ArchiveFile? kml;
    try {
      kml = ZipDecoder()
          .decodeBytes(bytes)
          .files
          .where((f) => f.isFile)
          .firstOrNull;
    } catch (_) {
      throw const WeatherException(WeatherError.invalidData);
    }
    final content = kml?.readBytes();
    if (content == null) throw const WeatherException(WeatherError.invalidData);
    return parseKml(latin1.decode(content), stationId);
  }

  static MosmixForecast parseKml(String kml, String stationId) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(kml);
    } on XmlException {
      throw const WeatherException(WeatherError.invalidData);
    }
    final times = [
      for (final e in doc.findAllElements('TimeStep', namespaceUri: '*'))
        DateTime.parse(e.innerText.trim()),
    ];
    if (times.isEmpty) throw const WeatherException(WeatherError.invalidData);
    final issueText = doc
        .findAllElements('IssueTime', namespaceUri: '*')
        .firstOrNull
        ?.innerText;

    final series = <String, List<double?>>{};
    for (final f in doc.findAllElements('Forecast', namespaceUri: '*')) {
      final name = f.attributes
          .firstWhere((a) => a.localName == 'elementName')
          .value;
      final raw =
          f.findElements('value', namespaceUri: '*').firstOrNull?.innerText ??
          '';
      series[name] = [
        for (final token in raw.trim().split(RegExp(r'\s+')))
          double.tryParse(token),
      ];
    }

    double? at(String key, int i) {
      final s = series[key];
      return s == null || i >= s.length ? null : s[i];
    }

    double? kelvin(double? v) => v == null ? null : v - 273.15;

    final hours = <HourlyForecast>[
      for (var i = 0; i < times.length; i++)
        HourlyForecast(
          time: times[i],
          temperature: kelvin(at('TTT', i)),
          dewPoint: kelvin(at('Td', i)),
          pressure: at('PPPP', i) == null ? null : at('PPPP', i)! / 100,
          windSpeed: at('FF', i),
          windDirection: at('DD', i),
          windGust: at('FX1', i),
          cloudCover: at('N', i),
          precipitation: at('RR1c', i),
          precipitationProbability: at('R101', i),
          sunshineMinutes: at('SunD1', i) == null ? null : at('SunD1', i)! / 60,
          visibility: at('VV', i),
          weatherCode: at('ww', i)?.round(),
        ),
    ];
    return MosmixForecast(
      stationId: stationId,
      issueTime: issueText == null
          ? times.first
          : DateTime.parse(issueText.trim()),
      hours: hours,
    );
  }
}
