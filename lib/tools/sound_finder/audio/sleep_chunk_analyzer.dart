import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../../helpers/wav_decoder.dart';
import 'db_scale.dart';
import 'fft.dart';

/// [impulse] is a knock or bang; coughs have their own [cough].
enum SleepSoundCategory {
  snore,
  speech,
  cough,
  impulse,
  movement,
  steady,
  other,
}

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
    this.highRatio = 0,
    this.harmonicity = 0,
    this.attackMs = 0,
    this.peakAmplitude = 0,
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

  /// Share of power above 2 kHz.
  final double highRatio;

  /// Pitch strength 0..1: voiced snoring and talking score high, rustling low.
  final double harmonicity;

  /// Fastest burst onset; coughs and knocks jump, snores swell.
  final int attackMs;

  /// Largest absolute sample in the file.
  final double peakAmplitude;

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
    'highRatio': _round(highRatio, 100),
    'flatness': _round(flatness, 100),
    'harmonicity': _round(harmonicity, 100),
    'attackMs': attackMs,
    'peakAmplitude': _round(peakAmplitude, 100000),
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
      highRatio: d('highRatio'),
      flatness: d('flatness'),
      harmonicity: d('harmonicity'),
      attackMs: i('attackMs'),
      peakAmplitude: d('peakAmplitude'),
      periodicity: d('periodicity'),
      periodSec: d('periodSec'),
    );
  }

  static double _round(double v, int f) => (v * f).roundToDouble() / f;
}

/// Offline, dependency-free classifier. Each burst is scored on its own, then
/// the scores are pooled by loudness and topped up by chunk-wide rhythm. The
/// thresholds are heuristics for a phone near the bed, not a trained model, so
/// the confidence is a relative score rather than a probability.
class SleepChunkAnalyzer {
  SleepChunkAnalyzer._();

  /// Bump when the features or thresholds change so old results get redone.
  static const int version = 2;

  /// Frames this quiet are digital silence (mic restart), not the room.
  static const double _silentDb = -140;
  static const int _framesPerBurst = 6;
  static const int _pitchFramesPerBurst = 3;
  static const int _maxBursts = 40;

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

    final audible = [
      for (final v in db)
        if (v > _silentDb) v,
    ]..sort();
    final floorDb = audible.isEmpty
        ? -180.0
        : audible[(audible.length * 0.2).floor()];
    final peakDb = audible.isEmpty ? -180.0 : audible.last;
    final contrast = peakDb - floorDb;
    final activeThr = math.max(floorDb + 8, peakDb - 30);

    final active = List<bool>.generate(frameCount, (f) => db[f] >= activeThr);
    final segments = [
      for (final s in _segments(active, (150 / hopMs).ceil()))
        ..._splitOnsets(db, s),
    ];

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

    final (periodicity, periodSec) = _periodicity(db, floorDb, hopMs, 1.2, 7.0);
    final (syllabic, _) = _periodicity(db, floorDb, hopMs, 0.12, 0.4);

    final ranked = [...segments]
      ..sort((a, b) => _peak(db, b).compareTo(_peak(db, a)));
    final picked = ranked.take(_maxBursts).toSet();
    final total = Float64List(frame ~/ 2);
    final bursts = <_Burst>[
      for (final s in segments)
        if (picked.contains(s))
          _burst(samples, sampleRate, frame, hop, hopMs, db, floorDb, s, total),
    ];
    final spectrum = _features(total, sampleRate / frame);

    final totalMs = samples.length * 1000 / sampleRate;
    final activeMs = activeFrames * hopMs;
    final activeRatio = totalMs <= 0 ? 0.0 : activeMs / totalMs;

    final (category, confidence) = _classify(
      bursts: bursts,
      activeRatio: activeRatio,
      contrast: contrast,
      periodicity: periodicity,
      periodSec: periodSec,
      syllabic: syllabic,
    );

    final weights = [for (final b in bursts) b.weight(peakDb)];
    final weightSum = weights.fold(0.0, (a, w) => a + w);
    double pooled(double Function(_Burst b) pick) {
      if (weightSum <= 0) return 0;
      var acc = 0.0;
      for (var i = 0; i < bursts.length; i++) {
        acc += pick(bursts[i]) * weights[i];
      }
      return acc / weightSum;
    }

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
      highRatio: spectrum.highRatio,
      flatness: spectrum.flatness,
      harmonicity: pooled((b) => b.harmonicity),
      attackMs: bursts.isEmpty
          ? 0
          : (bursts.map((b) => b.attackSec).reduce(math.min) * 1000).round(),
      peakAmplitude: samples.fold(0.0, (a, v) => math.max(a, v.abs())),
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

  /// Splits a run where the level dips and jumps back sharply, so a fit of
  /// coughs or a series of knocks counts as separate bursts.
  static List<(int, int)> _splitOnsets(Float64List db, (int, int) s) {
    final out = <(int, int)>[];
    var start = s.$1;
    var low = db[start];
    var high = db[start];
    for (var f = start + 1; f <= s.$2; f++) {
      if (high - low >= 10 && db[f] - low >= 10 && db[f] - db[f - 1] >= 6) {
        out.add((start, f - 1));
        start = f;
        high = db[f];
        low = db[f];
        continue;
      }
      if (db[f] > high) {
        high = db[f];
        low = db[f];
      } else {
        low = math.min(low, db[f]);
      }
    }
    out.add((start, s.$2));
    return out;
  }

  static double _peak(Float64List db, (int, int) s) {
    var best = db[s.$1];
    for (var f = s.$1 + 1; f <= s.$2; f++) {
      best = math.max(best, db[f]);
    }
    return best;
  }

  /// Shape and spectrum of one burst; its frame spectra also go into [total].
  static _Burst _burst(
    Float32List samples,
    int sampleRate,
    int frame,
    int hop,
    double hopMs,
    Float64List db,
    double floorDb,
    (int, int) s,
    Float64List total,
  ) {
    final (a, b) = s;
    var peakFrame = a;
    for (var f = a + 1; f <= b; f++) {
      if (db[f] > db[peakFrame]) peakFrame = f;
    }
    final peakDb = db[peakFrame];

    // Time from 20 dB below the peak to 3 dB below it: a cough or knock gets
    // there within a frame or two, a snore or rustle swells over many.
    var from = a;
    while (from < peakFrame && db[from] < peakDb - 20) {
      from++;
    }
    var to = from;
    while (to < peakFrame && db[to] < peakDb - 3) {
      to++;
    }
    final attackSec = (to - from) * hopMs / 1000;

    var decayEnd = peakFrame;
    while (decayEnd < b && db[decayEnd] > peakDb - 15) {
      decayEnd++;
    }

    final frames = [for (var f = a; f <= b; f++) f]
      ..sort((x, y) => db[y].compareTo(db[x]));
    final power = Float64List(frame ~/ 2);
    final buf = Float64List(frame);
    var binHz = sampleRate / frame;
    final pitch = <double>[];
    final strength = <double>[];
    for (final f in frames.take(_pitchFramesPerBurst)) {
      final (r, hz) = _pitch(samples, f * hop, frame * 2, sampleRate);
      strength.add(r);
      if (r > 0) pitch.add(hz);
    }
    for (final f in frames.take(_framesPerBurst)) {
      final start = f * hop;
      for (var i = 0; i < frame; i++) {
        final idx = start + i;
        buf[i] = idx < samples.length ? samples[idx] : 0;
      }
      final spec = Fft.magnitudeSpectrum(buf, sampleRate);
      binHz = spec.binHz;
      for (var i = 0; i < power.length; i++) {
        final p = spec.magnitudes[i] * spec.magnitudes[i];
        power[i] += p;
        total[i] += p;
      }
    }
    strength.sort();
    pitch.sort();
    final spectrum = _features(power, binHz);
    return _Burst(
      durSec: ((b - a + 1) * hopMs + hopMs) / 1000,
      attackSec: attackSec,
      decaySec: (decayEnd - peakFrame) * hopMs / 1000,
      reachedDecay: db[decayEnd] <= peakDb - 15,
      peakDb: peakDb,
      centroid: spectrum.centroid,
      highRatio: spectrum.highRatio,
      flatness: spectrum.flatness,
      harmonicity: strength.isEmpty ? 0 : strength[strength.length ~/ 2],
      pitchHz: pitch.isEmpty ? 0 : pitch[pitch.length ~/ 2],
    );
  }

  static _Spectrum _features(Float64List power, double binHz) {
    final lo = (50 / binHz).ceil();
    final hi = math.min(power.length - 1, (8000 / binHz).floor());
    var total = 0.0, weighted = 0.0, low = 0.0, high = 0.0, best = 0.0;
    var dominant = 0.0;
    var logSum = 0.0, flatSum = 0.0;
    var flatBins = 0;
    for (var i = lo; i <= hi; i++) {
      final p = power[i];
      final hz = i * binHz;
      total += p;
      weighted += p * hz;
      if (hz < 400) low += p;
      if (hz >= 2000) high += p;
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
    if (total <= 0) return const _Spectrum(0, 0, 0, 0, 0);
    final flatness = flatBins == 0 || flatSum <= 0
        ? 0.0
        : math.exp(logSum / flatBins) / (flatSum / flatBins);
    return _Spectrum(
      weighted / total,
      dominant,
      low / total,
      high / total,
      flatness,
    );
  }

  /// Pitch strength and frequency between 30 and 500 Hz (palate flutter up to
  /// voice) from the normalized autocorrelation of a decimated,
  /// pre-emphasized window. Only a peak that rises clearly above the dip
  /// before it counts: low-passed noise such as rustling bedding correlates at
  /// short lags too, but never forms a peak.
  static (double, double) _pitch(
    Float32List samples,
    int start,
    int length,
    int sampleRate,
  ) {
    final step = math.max(1, sampleRate ~/ 11025);
    final rate = sampleRate / step;
    final n = length ~/ step;
    final y = Float64List(n);
    for (var i = 0; i < n; i++) {
      var acc = 0.0;
      for (var k = 0; k < step; k++) {
        final idx = start + i * step + k;
        if (idx < samples.length) acc += samples[idx];
      }
      y[i] = acc / step;
    }
    for (var i = n - 1; i > 0; i--) {
      y[i] -= 0.9 * y[i - 1];
    }
    final minLag = (rate / 500).floor();
    final maxLag = math.min(n * 2 ~/ 3, (rate / 30).ceil());
    final r = Float64List(maxLag + 2);
    for (var lag = 1; lag <= maxLag + 1; lag++) {
      var xy = 0.0, xx = 0.0, yy = 0.0;
      for (var i = 0; i + lag < n; i++) {
        xy += y[i] * y[i + lag];
        xx += y[i] * y[i];
        yy += y[i + lag] * y[i + lag];
      }
      r[lag] = xx <= 0 || yy <= 0 ? 0 : xy / math.sqrt(xx * yy);
    }
    final peaks = <int>[];
    var dip = r[1];
    for (var lag = 2; lag <= maxLag; lag++) {
      dip = math.min(dip, r[lag]);
      if (lag < minLag) continue;
      final isPeak = r[lag] >= r[lag - 1] && r[lag] >= r[lag + 1];
      if (isPeak && r[lag] - dip >= 0.3) peaks.add(lag);
    }
    if (peaks.isEmpty) return (0, 0);
    final best = peaks.map((l) => r[l]).reduce(math.max);
    // Multiples of the period correlate as well; the shortest strong one is
    // the pitch.
    final lag = peaks.firstWhere((l) => r[l] >= 0.85 * best);
    return (best.clamp(0.0, 1.0), rate / lag);
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
    required List<_Burst> bursts,
    required double activeRatio,
    required double contrast,
    required double periodicity,
    required double periodSec,
    required double syllabic,
  }) {
    if (bursts.isEmpty || (activeRatio > 0.8 && contrast < 15)) {
      return (SleepSoundCategory.steady, contrast < 10 ? 0.8 : 0.6);
    }

    final loudest = bursts.fold(-180.0, (a, b) => math.max(a, b.peakDb));
    final scores = <SleepSoundCategory, double>{};
    var weightSum = 0.0;
    var coughLike = 0;
    for (final b in bursts) {
      final w = b.weight(loudest);
      weightSum += w;
      final burst = _scoreBurst(b);
      if ((burst[SleepSoundCategory.cough] ?? 0) >= 0.6) coughLike++;
      burst.forEach((c, v) => scores[c] = (scores[c] ?? 0) + v * w);
    }
    scores.updateAll((_, v) => weightSum <= 0 ? 0 : v / weightSum);

    void boost(SleepSoundCategory c, double by) =>
        scores[c] = (scores[c] ?? 0) + by;
    final rhythmic =
        periodicity > 0.35 &&
        periodSec >= 1.5 &&
        periodSec <= 7 &&
        bursts.length >= 2;
    // Breathing rhythm only confirms snoring when the bursts are also voiced,
    // otherwise heavy breathing or rhythmic rustling would pass for it.
    if (rhythmic && (scores[SleepSoundCategory.snore] ?? 0) >= 0.3) {
      boost(SleepSoundCategory.snore, 0.25);
    }
    if (syllabic > 0.25) boost(SleepSoundCategory.speech, 0.2);
    if (coughLike >= 2) boost(SleepSoundCategory.cough, 0.1);
    if (!rhythmic) boost(SleepSoundCategory.movement, 0.05);

    final best = scores.entries.reduce((a, b) => b.value > a.value ? b : a);
    if (best.value < 0.45) return (SleepSoundCategory.other, best.value);
    return (best.key, best.value.clamp(0.0, 1.0));
  }

  static Map<SleepSoundCategory, double> _scoreBurst(_Burst b) {
    final explosive = b.attackSec <= 0.05;
    final swelling = b.attackSec >= 0.15;
    final noisy = b.harmonicity < 0.3;
    final voiced = b.harmonicity >= 0.5;
    final bright = b.highRatio >= 0.08 || b.centroid >= 900;

    var impulse = 0.0;
    if (b.durSec <= 0.15) {
      impulse += 0.45;
    } else if (b.durSec <= 0.22) {
      impulse += 0.2;
    }
    if (explosive) impulse += 0.25;
    if (b.reachedDecay && b.decaySec <= 0.1) impulse += 0.2;

    var cough = 0.0;
    if (b.durSec > 0.15 && b.durSec <= 1.0) cough += 0.3;
    if (explosive) cough += 0.3;
    if (bright) cough += 0.2;
    if (b.reachedDecay) cough += 0.1;
    // A cough is a burst of air, mostly noise; voiced onsets are syllables.
    if (b.harmonicity < 0.4) {
      cough += 0.1;
    } else if (voiced) {
      cough -= 0.35;
    }

    var snore = 0.0;
    if (voiced) {
      snore += 0.35;
    } else if (b.harmonicity >= 0.35) {
      snore += 0.15;
    } else if (b.harmonicity < 0.2) {
      snore -= 0.15;
    }
    if (b.centroid < 900 && b.highRatio < 0.06) snore += 0.2;
    if (b.durSec >= 0.4 && b.durSec <= 3.5) snore += 0.15;
    if (swelling) snore += 0.15;
    if (explosive) snore -= 0.2;

    var movement = 0.0;
    if (b.harmonicity < 0.15) {
      movement += 0.4;
    } else if (noisy) {
      movement += 0.3;
    }
    if (b.highRatio >= 0.1 || b.flatness >= 0.2) {
      movement += 0.2;
    } else if (b.flatness >= 0.07) {
      // Bedding close to the mic is mostly low-pitched yet still noise-like.
      movement += 0.1;
    }
    if (b.durSec >= 0.4) movement += 0.15;
    if (!explosive) movement += 0.1;

    var speech = 0.0;
    if (voiced) speech += 0.25;
    if (b.centroid >= 350 && b.centroid <= 3000) speech += 0.15;
    if (b.pitchHz >= 75 && b.pitchHz <= 350) speech += 0.1;
    if (b.durSec >= 0.3) speech += 0.05;

    return {
      SleepSoundCategory.impulse: impulse,
      SleepSoundCategory.cough: cough,
      SleepSoundCategory.snore: snore,
      SleepSoundCategory.movement: movement,
      SleepSoundCategory.speech: speech,
    };
  }
}

class _Burst {
  const _Burst({
    required this.durSec,
    required this.attackSec,
    required this.decaySec,
    required this.reachedDecay,
    required this.peakDb,
    required this.centroid,
    required this.highRatio,
    required this.flatness,
    required this.harmonicity,
    required this.pitchHz,
  });

  final double durSec;
  final double attackSec;
  final double decaySec;
  final bool reachedDecay;
  final double peakDb;
  final double centroid;
  final double highRatio;
  final double flatness;
  final double harmonicity;
  final double pitchHz;

  /// Louder and longer bursts speak for the chunk; a faint tail does not.
  double weight(double loudestDb) =>
      math.sqrt(durSec.clamp(0.05, 3.0)) *
      math.pow(10, (peakDb - loudestDb) / 20);
}

class _Spectrum {
  const _Spectrum(
    this.centroid,
    this.dominant,
    this.lowRatio,
    this.highRatio,
    this.flatness,
  );
  final double centroid;
  final double dominant;
  final double lowRatio;
  final double highRatio;
  final double flatness;
}
