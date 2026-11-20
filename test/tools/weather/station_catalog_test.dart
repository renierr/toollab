// A hang should fail fast instead of after the 10-minute default.
@Timeout(Duration(minutes: 1))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/weather/api/station_catalog.dart';

void main() {
  final catalog = StationCatalog.fromJson(
    File(StationCatalog.assetPath).readAsStringSync(),
  );
  const eschborn = (lat: 50.150, lon: 8.561);

  test('decimal coordinates from the degree.minute catalog', () {
    final westend = catalog.byId('L841')!;
    expect(westend.latitude, closeTo(50.133, 0.001));
    expect(westend.longitude, closeTo(8.667, 0.001));
  });

  test('Eschborn gets a nearby forecast station', () {
    final nearest = catalog.nearest(eschborn.lat, eschborn.lon).first;
    expect(nearest.distanceKm, lessThan(12));
  });

  test('height difference demotes summit stations', () {
    final ranked = catalog.nearest(eschborn.lat, eschborn.lon, elevation: 130);
    expect(ranked.first.station.elevation, lessThan(300));
  });

  test('observation stations near Eschborn include Frankfurt airport', () {
    final obs = catalog.nearest(
      eschborn.lat,
      eschborn.lon,
      observationsOnly: true,
    );
    expect(obs.map((m) => m.station.id), contains('10637'));
    expect(obs.every((m) => m.station.hasObservations), isTrue);
  });

  test('search prefers prefix matches', () {
    final hits = catalog.search('frankfurt');
    expect(hits, isNotEmpty);
    expect(hits.first.name.toLowerCase(), startsWith('frankfurt'));
  });
}
