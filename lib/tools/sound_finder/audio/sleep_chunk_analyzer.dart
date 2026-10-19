import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../../helpers/wav_decoder.dart';
import 'db_scale.dart';
import 'fft.dart';

enum SleepSoundCategory { snore, speech, impulse, movement, steady, other }

/// Acoustic features of one sleep chunk plus the heuristic category they
/// point to. Offsets are milliseconds from the start of the chunk.
class SleepChunkAnalysis {
  const SleepChunkAnalysis({
    required this.category,
    required this.confidence,
    required this.levelDb,
    required this.floorDb,
    required this.activeMs,
    required this.firstActiveMs,
    required this.lastActiveMs,
    required this.loudestMs,
    required this.bursts,
    required this.centroidHz,
    required this.dominantHz,
    required this.lowRatio,
    required this.flatness,
    required this.periodicity,
    required this.periodSec,
  });

  final SleepSoundCategory category;
  final double confidence;
  final double levelDb;
  final double floorDb;
  final int activeMs;
  final int firstActiveMs;
  final int lastActiveMs;
  final int loudestMs;
  final int bursts;
  final double centroidHz;
  final double dominantHz;
  final double lowRatio;
  final double flatness;
  final double periodicity;
  final double periodSec;

  Map<String, dynamic> toJson() => {
    'category': category.name,
    'confidence': _round(confidence, 100),
    'levelDb': _round(levelDb, 10),
    'floorDb': _round(floorDb, 10),
    'activeMs': activeMs,
    'firstActiveMs': firstActiveMs,
    'lastActiveMs': lastActiveMs,
    'loudestMs': loudestMs,
    'bursts': bursts,
    'centroidHz': centroidHz.round(),
    'dominantHz': dominantHz.round(),
    'lowRatio': _round(lowRatio, 100),
    'flatness': _round(flatness, 100),
    'periodicity': _round(periodicity, 100),
    'periodSec': _round(periodSec, 10),
  };

  factory SleepChunkAnalysis.fromJson(Map<String, dynamic> json) {
    double d(String k) => (json[k] as num?)?.toDouble() ?? 0;
    int i(String k) => (json[k] as num?)?.toInt() ?? 0;
    return SleepChunkAnalysis(
      category: SleepSoundCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => SleepSoundCategory.other,
      ),
      confidence: d('confidence'),
      levelDb: d('levelDb'),
      floorDb: d('floorDb'),
      activeMs: i('activeMs'),
      firstActiveMs: i('firstActiveMs'),
      lastActiveMs: i('lastActiveMs'),
      loudestMs: i('loudestMs'),
      bursts: i('bursts'),
      centroidHz: d('centroidHz'),
      dominantHz: d('dominantHz'),
      lowRatio: d('lowRatio'),
      flatness: d('flatness'),
      periodicity: d('periodicity'),
      periodSec: d('periodSec'),
    );
  }

  static double _round(double v, int f) => (v * f).roundToDouble() / f;
}

/// Offline, dependency-free classifier. The thresholds are heuristics tuned
/// for a phone near the bed, not a trained model, so the confidence is a
/// relative score rather than a probability.
class SleepChunkAnalyzer {
  SleepChunkAnalyzer._();

  /// Bump when the features or thresholds change so old results get redone.
  static const int version = 1;

  static SleepChunkAnalysis? analyzeFile(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    final wav = WavDecoder.decode(file.readAsBytesSync());
    if (wav == null || wav.samples.isEmpty) return null;
    return analyze(wav.samples, wav.sampleRate);
  }

  static SleepChunkAnalysis analyze(Float32List samples, int sampleRate) {
    final frame = sampleRate >= 32000 ? 2048 : 1024;
    final hop = frame ~/ 2;
    final hopMs = hop * 1000 / sampleRate;
    final frameCount = samples.length < frame
        ? 1
        : (samples.length - frame) ~/ hop + 1;

    final db = Float64List(frameCount);
    for (var f = 0; f < frameCount; f++) {
      final start = f * hop;
      final end = math.min(start + frame, samples.length);
      var sum = 0.0;
      for (var i = start; i < end; i++) {
        sum += samples[i] * samples[i];
      }
      final rms = math.sqrt(sum / math.max(1, end - start));
      db[f] = ampToDb(rms, floor: -180);
    }

    final sorted = Float64List.fromList(db)..sort();
    final floorDb = sorted[(sorted.length * 0.2).floor()];
    final peakDb = sorted.last;
    final contrast = peakDb - floorDb;
    final activeThr = math.max(floorDb + 8, peakDb - 30);

    final active = List<bool>.generate(frameCount, (f) => db[f] >= activeThr);
    final segments = _segments(active, (150 / hopMs).ceil());

    var loudest = 0;
    for (var f = 1; f < frameCount; f++) {
      if (db[f] > db[loudest]) loudest = f;
    }
    final activeFrames = active.where((a) => a).length;
    var levelSum = 0.0;
    for (var f = 0; f < frameCount; f++) {
      if (active[f]) levelSum += db[f];
    }
    final levelDb = activeFrames == 0 ? peakDb : levelSum / activeFrames;

    final spectrum = _spectrum(samples, sampleRate, frame, hop, active, db);
    final (periodicity, periodSec) = _periodicity(db, floorDb, hopMs, 1.2, 7.0);
    final (syllabic, _) = _periodicity(db, floorDb, hopMs, 0.12, 0.4);

    final totalMs = samples.length * 1000 / sampleRate;
    final activeMs = activeFrames * hopMs;
    final activeRatio = totalMs <= 0 ? 0.0 : activeMs / totalMs;
    final meanBurstSec = segments.isEmpty
        ? 0.0
        : segments.fold<int>(0, (a, s) => a + s.$2 - s.$1 + 1) *
              hopMs /
              segments.length /
              1000;

    final (category, confidence) = _classify(
      bursts: segments.length,
      activeRatio: activeRatio,
      contrast: contrast,
      meanBurstSec: meanBurstSec,
      centroid: spectrum.centroid,
      dominant: spectrum.dominant,
      lowRatio: spectrum.lowRatio,
      flatness: spectrum.flatness,
      periodicity: periodicity,
      periodSec: periodSec,
      syllabic: syllabic,
    );

    return SleepChunkAnalysis(
      category: category,
      confidence: confidence,
      levelDb: levelDb,
      floorDb: floorDb,
      activeMs: activeMs.round(),
      firstActiveMs: segments.isEmpty ? 0 : (segments.first.$1 * hopMs).round(),
      lastActiveMs: segments.isEmpty
          ? totalMs.round()
          : math.min(totalMs, (segments.last.$2 + 2) * hopMs).round(),
      loudestMs: (loudest * hopMs).round(),
      bursts: segments.length,
      centroidHz: spectrum.centroid,
      dominantHz: spectrum.dominant,
      lowRatio: spectrum.lowRatio,
      flatness: spectrum.flatness,
      periodicity: periodicity,
      periodSec: periodSec,
    );
  }

  /// Runs of active frames, bridging gaps up to [maxGap] frames.
  static List<(int, int)> _segments(List<bool> active, int maxGap) {
    final out = <(int, int)>[];
    int? start;
    var last = -1;
    for (var f = 0; f < active.length; f++) {
      if (!active[f]) continue;
      if (start != null && f - last - 1 > maxGap) {
        out.add((start, last));
        start = null;
      }
      start ??= f;
      last = f;
    }
    if (start != null) out.add((start, last));
    return out;
  }

  static _Spectrum _spectrum(
    Float32List samples,
    int sampleRate,
    int frame,
    int hop,
    List<bool> active,
    Float64List db,
  ) {
    final picks = <int>[
      for (var f = 0; f < active.length; f++)
        if (active[f]) f,
    ];
    if (picks.isEmpty) {
      picks.addAll(List.generate(active.length, (f) => f));
    }
    // Loudest frames carry the character of the sound; cap them for cost.
    picks.sort((a, b) => db[b].compareTo(db[a]));
    final use = picks.take(48);

    final power = Float64List(frame ~/ 2);
    final buf = Float64List(frame);
    var binHz = sampleRate / frame;
    for (final f in use) {
      final start = f * hop;
      for (var i = 0; i < frame; i++) {
        final idx = start + i;
        buf[i] = idx < samples.length ? samples[idx] : 0;
      }
      final spec = Fft.magnitudeSpectrum(buf, sampleRate);
      binHz = spec.binHz;
      for (var i = 0; i < power.length; i++) {
        power[i] += spec.magnitudes[i] * spec.magnitudes[i];
      }
    }

    final lo = (50 / binHz).ceil();
    final hi = math.min(power.length - 1, (8000 / binHz).floor());
    var total = 0.0, weighted = 0.0, low = 0.0, best = 0.0;
    var dominant = 0.0;
    var logSum = 0.0, flatSum = 0.0;
    var flatBins = 0;
    for (var i = lo; i <= hi; i++) {
      final p = power[i];
      final hz = i * binHz;
      total += p;
      weighted += p * hz;
      if (hz < 400) low += p;
      if (p > best) {
        best = p;
        dominant = hz;
      }
      if (hz >= 100 && hz <= 6000) {
        logSum += math.log(p + 1e-20);
        flatSum += p;
        flatBins++;
      }
    }
    if (total <= 0) return const _Spectrum(0, 0, 0, 0);
    final flatness = flatBins == 0 || flatSum <= 0
        ? 0.0
        : math.exp(logSum / flatBins) / (flatSum / flatBins);
    return _Spectrum(weighted / total, dominant, low / total, flatness);
  }

  /// Strongest normalized autocorrelation of the level envelope between
  /// [minSec] and [maxSec], and the lag where it occurs.
  static (double, double) _periodicity(
    Float64List db,
    double floorDb,
    double hopMs,
    double minSec,
    double maxSec,
  ) {
    final n = db.length;
    final e = Float64List(n);
    var mean = 0.0;
    for (var i = 0; i < n; i++) {
      e[i] = math.max(db[i], floorDb) - floorDb;
      mean += e[i];
    }
    mean /= n;
    var energy = 0.0;
    for (var i = 0; i < n; i++) {
      e[i] -= mean;
      energy += e[i] * e[i];
    }
    if (energy <= 1e-9) return (0, 0);

    final minLag = math.max(1, (minSec * 1000 / hopMs).round());
    final maxLag = math.min(n ~/ 2, (maxSec * 1000 / hopMs).round());
    var best = 0.0;
    var bestLag = 0;
    for (var lag = minLag; lag <= maxLag; lag++) {
      var acc = 0.0;
      for (var i = 0; i + lag < n; i++) {
        acc += e[i] * e[i + lag];
      }
      final r = (acc / energy) * n / (n - lag);
      if (r > best) {
        best = r;
        bestLag = lag;
      }
    }
    return (best.clamp(0.0, 1.0), bestLag * hopMs / 1000);
  }

  static (SleepSoundCategory, double) _classify({
    required int bursts,
    required double activeRatio,
    required double contrast,
    required double meanBurstSec,
    required double centroid,
    required double dominant,
    required double lowRatio,
    required double flatness,
    required double periodicity,
    required double periodSec,
    required double syllabic,
  }) {
    if (bursts == 0 || (activeRatio > 0.8 && contrast < 15)) {
      return (SleepSoundCategory.steady, contrast < 10 ? 0.8 : 0.6);
    }

    var snore = 0.0;
    if (lowRatio > 0.5) {
      snore += 0.35;
    } else if (dominant < 400) {
      snore += 0.15;
    }
    if (centroid < 900) snore += 0.15;
    if (periodicity > 0.35 && periodSec >= 1.5 && periodSec <= 7) snore += 0.3;
    if (bursts >= 2 && meanBurstSec >= 0.3 && meanBurstSec <= 3) snore += 0.2;

    var speech = 0.0;
    if (centroid >= 400 && centroid <= 2500) speech += 0.25;
    if (syllabic > 0.25) speech += 0.3;
    if (flatness < 0.3) speech += 0.15;
    if (bursts >= 2 && meanBurstSec < 2.5) speech += 0.15;
    if (lowRatio < 0.5) speech += 0.1;

    var impulse = 0.0;
    if (meanBurstSec < 0.35 && bursts <= 6) impulse += 0.45;
    if (contrast > 20) impulse += 0.25;
    if (activeRatio < 0.15) impulse += 0.2;

    var movement = 0.0;
    if (flatness > 0.35) movement += 0.35;
    if (centroid > 1500) movement += 0.25;
    if (periodicity < 0.3) movement += 0.1;
    if (meanBurstSec > 0.5) movement += 0.15;

    final scores = {
      SleepSoundCategory.snore: snore,
      SleepSoundCategory.speech: speech,
      SleepSoundCategory.impulse: impulse,
      SleepSoundCategory.movement: movement,
    };
    final best = scores.entries.reduce((a, b) => b.value > a.value ? b : a);
    if (best.value < 0.4) return (SleepSoundCategory.other, best.value);
    return (best.key, best.value.clamp(0.0, 1.0));
  }
}

class _Spectrum {
  const _Spectrum(this.centroid, this.dominant, this.lowRatio, this.flatness);
  final double centroid;
  final double dominant;
  final double lowRatio;
  final double flatness;
}
