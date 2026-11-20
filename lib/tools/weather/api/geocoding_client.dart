import 'dart:convert';

import '../models/geo_place.dart';
import 'weather_http.dart';

/// Nominatim; its usage policy allows one request per second and no
/// autocomplete, so callers search on submit only.
class GeocodingClient {
  const GeocodingClient();

  static const String countries = 'de,at,ch,nl,be,lu,fr,dk,pl,cz';

  static Uri url(String query, String language) =>
      Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'limit': '8',
        'countrycodes': countries,
        'accept-language': language,
      });

  Future<List<GeoPlace>> search(String query, {String language = 'de'}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final bytes = await WeatherHttp.getBytes(url(trimmed, language));
    return parse(utf8.decode(bytes));
  }

  static List<GeoPlace> parse(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const WeatherException(WeatherError.invalidData);
    }
    if (decoded is! List) {
      throw const WeatherException(WeatherError.invalidData);
    }
    final places = <GeoPlace>[];
    final seen = <String>{};
    for (final item in decoded) {
      if (item is! Map<String, dynamic> || item['lat'] is! String) continue;
      final place = GeoPlace.fromNominatim(item);
      if (seen.add(place.label)) places.add(place);
    }
    return places;
  }
}
