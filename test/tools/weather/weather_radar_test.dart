// A hang should fail fast instead of after the 10-minute default.
@Timeout(Duration(minutes: 1))
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/weather/api/dwd_radar.dart';
import 'package:tool_lab/tools/weather/models/radar_viewport.dart';
import 'package:tool_lab/tools/weather/models/rain_outlook.dart';
import 'package:tool_lab/tools/weather/radar_frame_store.dart';
import 'package:tool_lab/tools/weather/weather_radar_state.dart';

const _fixtures = 'test/fixtures/weather';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final caps = File('$_fixtures/radar_capabilities.xml').readAsStringSync();

  group('RadarTimeline', () {
    final timeline = RadarTimeline.parseCapabilities(caps);

    test('spans two hours back and every nowcast step in 5 minutes', () {
      expect(timeline.latestObserved, DateTime.utc(2026, 11, 20, 14, 30));
      expect(timeline.times.first, DateTime.utc(2026, 11, 20, 12, 30));
      expect(timeline.times.last, DateTime.utc(2026, 11, 20, 16, 30));
      expect(timeline.times.length, 49);
      expect(
        timeline.times[1].difference(timeline.times[0]),
        const Duration(minutes: 5),
      );
    });

    test('splits observed frames from the nowcast', () {
      expect(timeline.times[timeline.nowIndex], timeline.latestObserved);
      expect(timeline.isForecast(timeline.times.last), isTrue);
      expect(timeline.isForecast(timeline.times.first), isFalse);
    });

    test('rejects garbage', () {
      expect(() => RadarTimeline.parseCapabilities('<x/>'), throwsA(anything));
    });
  });

  group('RadarPalette', () {
    test('maps legend colours to their lower mm/h bound', () {
      expect(RadarPalette.intensity(0x33, 0xFF, 0xFF, 255), 0.1);
      expect(RadarPalette.intensity(0xFF, 0xFF, 0x01, 255), 5.0);
      expect(RadarPalette.intensity(0x00, 0x00, 0xFE, 255), 150);
    });

    test('ignores transparent and foreign pixels', () {
      expect(RadarPalette.intensity(0x33, 0xFF, 0xFF, 0), isNull);
      expect(RadarPalette.intensity(0x80, 0x80, 0x80, 255), isNull);
    });
  });

  group('RainOutlook', () {
    final times = List.generate(6, (i) => DateTime.utc(2026, 1, 1, 12, i * 5));

    test('rain soon', () {
      final o = RainOutlook.from([0, 0, 0, 0.5, 1, 1], times, 1)!;
      expect(o.kind, RainOutlookKind.rainSoon);
      expect(o.minutes, 10);
    });

    test('rain stops', () {
      final o = RainOutlook.from([1, 1, 0, 0, 0, 0], times, 0)!;
      expect(o.kind, RainOutlookKind.rainStops);
      expect(o.minutes, 10);
    });

    test('frames without an image are skipped', () {
      final o = RainOutlook.from([0, 0, double.nan, 0.5, 1, 1], times, 1)!;
      expect(o.kind, RainOutlookKind.rainSoon);
      expect(
        RainOutlook.from([0, 0, 0, 0, 0, double.nan], times, 1)!.kind,
        RainOutlookKind.dry,
      );
    });

    test('dry and unknown', () {
      expect(
        RainOutlook.from([0, 0, 0, 0, 0, 0], times, 1)!.kind,
        RainOutlookKind.dry,
      );
      expect(RainOutlook.from([0, 0, null, 0, 0, 0], times, 1), isNull);
    });
  });

  group('RadarViewport', () {
    final vp = RadarViewport.around(50.15, 8.56, const Size(400, 300));

    test('centre maps to the middle of the view', () {
      final p = vp.toScreenLatLon(50.15, 8.56);
      expect(p.dx, closeTo(200, .01));
      expect(p.dy, closeTo(150, .01));
    });

    test('an anchor keeps the place in the upper third', () {
      final upper = RadarViewport.around(
        50.15,
        8.56,
        const Size(400, 900),
        anchorY: 1 / 3,
      );
      final p = upper.toScreenLatLon(50.15, 8.56);
      expect(p.dx, closeTo(200, .01));
      expect(p.dy, closeTo(300, .01));
    });

    test('zoom keeps the point under the cursor', () {
      const focal = Offset(80, 60);
      final x = vp.centerX + (focal.dx - 200) * vp.resolution;
      final y = vp.centerY - (focal.dy - 150) * vp.resolution;
      final zoomed = vp.zoomAt(2, focal);
      final p = zoomed.toScreen(x, y);
      expect(p.dx, closeTo(focal.dx, .01));
      expect(p.dy, closeTo(focal.dy, .01));
      expect(zoomed.resolution, closeTo(vp.resolution / 2, .01));
    });

    test('panning stops at the radar coverage', () {
      final far = vp.panBy(const Offset(1e7, 0));
      expect(far.centerX, Mercator.coverage.left);
    });
  });

  test(
    'WeatherRadarState loads every frame and samples rain at the place',
    () async {
      final frame = File('$_fixtures/radar_frame.png').readAsBytesSync();
      var inFlight = 0;
      var maxInFlight = 0;
      Future<Uint8List> fetch(Uri uri) async {
        if (uri.queryParameters['request'] == 'GetCapabilities') {
          return Uint8List.fromList(caps.codeUnits);
        }
        inFlight++;
        maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
        await Future<void>.delayed(const Duration(milliseconds: 2));
        inFlight--;
        return frame;
      }

      var requests = 0;
      final store = _MemoryStore();
      final radar =
          WeatherRadarState(
              fetch: (uri) {
                requests++;
                return fetch(uri);
              },
              store: store,
            )
            ..focusOn(50.15, 8.56)
            ..attach()
            ..resize(const Size(400, 400));
      for (var i = 0; i < 1500 && radar.loadedCount < 49; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(radar.frameCount, 49);
      expect(radar.loadedCount, 49);
      expect(maxInFlight, lessThanOrEqualTo(8));
      expect(radar.rainSeries.every((v) => v != null), isTrue);
      expect(radar.index, radar.timeline!.nowIndex);

      // Reopening the tool serves every frame from the session store.
      radar
        ..detach()
        ..release();
      final before = requests;
      radar
        ..focusOn(50.15, 8.56)
        ..attach()
        ..resize(const Size(400, 400));
      for (var i = 0; i < 1500 && radar.loadedCount < 49; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(radar.loadedCount, 49);
      expect(requests - before, 0, reason: 'timeline and frames are kept');
      radar.dispose();
    },
  );

  test('a frame the server cannot render does not block loading', () async {
    final frame = File('$_fixtures/radar_frame.png').readAsBytesSync();
    final last = RadarTimeline.parseCapabilities(
      caps,
    ).times.last.toIso8601String();
    final radar =
        WeatherRadarState(
            store: _MemoryStore(),
            fetch: (uri) async {
              final q = uri.queryParameters;
              if (q['request'] == 'GetCapabilities') {
                return Uint8List.fromList(caps.codeUnits);
              }
              if (q['time'] == last) {
                return Uint8List.fromList(
                  '<ServiceExceptionReport>InvalidDimensionValue</ServiceExceptionReport>'
                      .codeUnits,
                );
              }
              return frame;
            },
          )
          ..focusOn(50.15, 8.56)
          ..attach()
          ..resize(const Size(400, 400));
    for (
      var i = 0;
      i < 1500 && (radar.timeline == null || radar.isLoading);
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(radar.isLoading, isFalse);
    expect(radar.loadedCount, 48);
    expect(radar.rainSeries.last!.isNaN, isTrue);
    radar.dispose();
  });

  test(
    'a preview loads only the current frame until the radar is enlarged',
    () async {
      final frame = File('$_fixtures/radar_frame.png').readAsBytesSync();
      var frames = 0;
      final radar =
          WeatherRadarState(
              store: _MemoryStore(),
              fetch: (uri) async {
                final q = uri.queryParameters;
                if (q['request'] == 'GetCapabilities') {
                  return Uint8List.fromList(caps.codeUnits);
                }
                if ((q['layers'] ?? '').contains('Niederschlagsradar')) {
                  frames++;
                }
                return frame;
              },
            )
            ..focusOn(50.15, 8.56)
            ..attach(full: false)
            ..resize(const Size(400, 240));
      for (
        var i = 0;
        i < 500 && (radar.timeline == null || radar.isLoading);
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(frames, 1);
      expect(radar.isLoaded(radar.timeline!.nowIndex), isTrue);

      radar.attach();
      for (var i = 0; i < 1500 && radar.isLoading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(radar.loadedCount, 49);
      expect(frames, 49);
      radar.dispose();
    },
  );

  test(
    'a reopened map shows the frame saved last time while loading',
    () async {
      final frame = File('$_fixtures/radar_frame.png').readAsBytesSync();
      final lasting = _MemoryLasting();
      WeatherRadarState open(Future<Uint8List> Function(Uri) fetch) =>
          WeatherRadarState(
              store: _MemoryStore(),
              lasting: lasting,
              fetch: fetch,
            )
            ..focusOn(50.15, 8.56)
            ..attach(full: false)
            ..resize(const Size(400, 240));

      final first = open(
        (uri) async => uri.queryParameters['request'] == 'GetCapabilities'
            ? Uint8List.fromList(caps.codeUnits)
            : frame,
      );
      for (
        var i = 0;
        i < 500 && (first.timeline == null || first.isLoading);
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      first.dispose();
      expect(lasting.keys.where((k) => k.startsWith('last:')), isNotEmpty);
      expect(lasting.keys.where((k) => k.startsWith('base:')), hasLength(2));

      final never = Completer<Uint8List>();
      final second = open((_) => never.future);
      for (var i = 0; i < 100 && second.frameAt(0) == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(second.timeline, isNull);
      expect(second.frameAt(0), isNotNull);
      expect(second.base, isNotNull);
      second.dispose();
    },
  );

  test('preview and full-screen views share one block', () {
    final small = RadarViewport.around(50.15, 8.56, const Size(380, 240));
    final large = RadarViewport.around(50.15, 8.56, const Size(380, 760));
    expect(RadarBlock.forViewport(small), RadarBlock.forViewport(large));
    final block = RadarBlock.forViewport(small);
    final panned = small.panBy(const Offset(30, 10));
    expect(RadarBlock.forViewport(panned, current: block), same(block));
  });

  test('blocks never request finer than the radar grid', () {
    final close = RadarViewport.around(
      50.15,
      8.56,
      const Size(380, 760),
      resolution: 100,
    );
    expect(RadarBlock.forViewport(close).resolution, greaterThanOrEqualTo(600));
  });
}

class _MemoryStore extends RadarFrameStore {
  final Map<String, Uint8List> _data = {};

  @override
  Future<Uint8List?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, Uint8List bytes) async => _data[key] = bytes;

  @override
  void dropMemory() {}

  @override
  Future<void> clear() async {}
}

class _MemoryLasting extends RadarLastingStore {
  final Map<String, Uint8List> _data = {};

  Iterable<String> get keys => _data.keys;

  @override
  Future<({Uint8List bytes, DateTime savedAt})?> read(String key) async {
    final bytes = _data[key];
    return bytes == null ? null : (bytes: bytes, savedAt: DateTime.now());
  }

  @override
  Future<void> write(String key, Uint8List bytes) async => _data[key] = bytes;
}
