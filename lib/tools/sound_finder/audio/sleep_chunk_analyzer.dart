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

/// One sound inside a chunk. A chunk can hold several, so the night timeline
/// shows what was heard instead of colouring a whole chunk with one label.
class SleepSubEvent {
  const SleepSubEvent({
    required this.startMs,
    required this.endMs,
    required this.category,
    required this.confidence,
    this.peakDb = -90,
  });

  final int startMs;
  final int endMs;
  final SleepSoundCategory category;
  final double confidence;
  final double peakDb;

  int get durationMs => math.max(0, endMs - startMs);

  Map<String, dynamic> toJson() => {
    'startMs': startMs,
    'endMs': endMs,
    'category': category.name,
    'confidence': _round(confidence, 100),
    'peakDb': _round(peakDb, 10),
  };

  factory SleepSubEvent.fromJson(Map<String, dynamic> json) => SleepSubEvent(
    startMs: (json['startMs'] as num?)?.toInt() ?? 0,
    endMs: (json['endMs'] as num?)?.toInt() ?? 0,
    category: SleepSoundCategory.values.firstWhere(
      (c) => c.name == json['category'],
      orElse: () => SleepSoundCategory.other,
    ),
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    peakDb: (json['peakDb'] as num?)?.toDouble() ?? -90,
  );

  static double _round(double v, int f) => (v * f).roundToDouble() / f;
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
    this.subEvents = const [],
    this.mixed = false,
    this.margin = 0,
    this.pitchStability = 0,
    this.clipped = 0,
    this.bands = const [],
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

  /// Per-sound breakdown, ordered by time. Empty for older analyses.
  final List<SleepSubEvent> subEvents;

  /// The chunk holds more than one sound, so [category] is only the longest.
  final bool mixed;

  /// Time-share gap between the longest and the second sound, 0..1.
  final double margin;

  /// 1 minus the median pitch jitter of the bursts, 0..1.
  final double pitchStability;

  /// Share of samples at full scale, 0..1.
  final double clipped;

  /// Octave-band power shares from 63 Hz to 8 kHz.
  final List<double> bands;

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
    if (subEvents.isNotEmpty)
      'subEvents': [for (final e in subEvents) e.toJson()],
    if (mixed) 'mixed': true,
    'margin': _round(margin, 100),
    'pitchStability': _round(pitchStability, 100),
    if (clipped > 0) 'clipped': _round(clipped, 10000),
    if (bands.isNotEmpty) 'bands': [for (final b in bands) _round(b, 100)],
  };

  factory SleepChunkAnalysis.fromJson(Map<String, dynamic> json) {
    double d(String k) => (json[k] as num?)?.toDouble() ?? 0;
    int i(String k) => (json[k] as num?)?.toInt() ?? 0;
    final rawBands = json['bands'];
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
      subEvents: [
        for (final raw in (json['subEvents'] as List? ?? const []))
          if (raw is Map<String, dynamic>) SleepSubEvent.fromJson(raw),
      ],
      mixed: json['mixed'] as bool? ?? false,
      margin: d('margin'),
      pitchStability: d('pitchStability'),
      clipped: d('clipped'),
      bands: rawBands is List
          ? [for (final b in rawBands) (b as num).toDouble()]
          : const [],
    );
  }

  static double _round(double v, int f) => (v * f).roundToDouble() / f;
}

/// Offline, dependency-free classifier. Every active run gets its own label,
/// then the chunk takes the label that covers the most time. Rhythm, syllable
/// rate and cough fits are chunk-wide boosts. The thresholds are heuristics for
/// a phone near the bed, not a trained model, so confidence is a relative
/// score rather than a probability.
class SleepChunkAnalyzer {
  SleepChunkAnalyzer._();

  /// Bump when the features or thresholds change so old results get redone.
  static const int version = 3;

  /// Frames this quiet are digital silence (mic restart), not the room.
  static const double _silentDb = -140;
  static const int _pitchFramesPerBurst = 3;
  static const int _spectrumFramesPerBurst = 6;
  static const int _maxBursts = 240;
  static const double _highPassHz = 35;
  static const double _bandLowHz = 40;
  static const double _bandHighHz = 12000;

  static SleepChunkAnalysis? analyzeFile(String path, {double? noiseFloorDb}) {
    final file = File(path);
    if (!file.existsSync()) return null;
    final wav = WavDecoder.decode(file.readAsBytesSync());
    if (wav == null || wav.samples.isEmpty) return null;
    return analyze(wav.samples, wav.sampleRate, noiseFloorDb: noiseFloorDb);
  }

  static SleepChunkAnalysis analyze(
    Float32List samples,
    int sampleRate, {
    double? noiseFloorDb,
  }) {
    if (samples.isEmpty || sampleRate <= 0) return _empty();
    final frame = sampleRate >= 32000 ? 2048 : 1024;
    final hop = frame ~/ 2;
    final hopMs = hop * 1000 / sampleRate;
    final frameCount = samples.length < frame
        ? 1
        : (samples.length - frame) ~/ hop + 1;

    final hp = _highPass(samples, sampleRate);
    final clipped = _clippedFraction(samples);

    final db = Float64List(frameCount);
    for (var f = 0; f < frameCount; f++) {
      final start = f * hop;
      final end = math.min(start + frame, samples.length);
      var sum = 0.0;
      for (var i = start; i < end; i++) {
        sum += hp[i] * hp[i];
      }
      final rms = math.sqrt(sum / math.max(1, end - start));
      db[f] = ampToDb(rms, floor: -180);
    }

    final audible = [
      for (final v in db)
        if (v > _silentDb) v,
    ]..sort();
    final localFloor = audible.isEmpty
        ? -180.0
        : audible[(audible.length * 0.2).floor()];
    // The session floor from the recorder's quiet chunks beats a floor guessed
    // inside a chunk that may be loud from end to end.
    final floorDb = noiseFloorDb == null
        ? localFloor
        : math.min(localFloor, noiseFloorDb);
    final peakDb = audible.isEmpty ? -180.0 : audible.last;
    final contrast = peakDb - floorDb;

    final smooth = _median3(db);
    final activeThr = floorDb + 8;
    final releaseThr = floorDb + 4;
    final maxGap = math.max(1, (150 / hopMs).ceil());
    final minFrames = math.max(1, (60 / hopMs).ceil());
    final runs = _activeSegments(
      smooth,
      activeThr,
      releaseThr,
      maxGap,
      minFrames,
    );
    final segments = <(int, int)>[
      for (final run in runs) ..._splitOnsets(smooth, run),
    ];

    var loudest = 0;
    for (var f = 1; f < frameCount; f++) {
      if (db[f] > db[loudest]) loudest = f;
    }
    var activeFrames = 0;
    var levelSum = 0.0;
    for (var f = 0; f < frameCount; f++) {
      if (db[f] >= activeThr) {
        activeFrames++;
        levelSum += db[f];
      }
    }
    final levelDb = activeFrames == 0 ? peakDb : levelSum / activeFrames;

    final (periodicity, periodSec) = _rhythm(segments, hopMs, db, floorDb);
    final (syllabic, _) = _periodicity(db, floorDb, hopMs, 0.12, 0.4);

    final total = Float64List(frame ~/ 2);
    final keep = List.generate(
      segments.length,
      (i) => i,
    )..sort((a, b) => _peak(db, segments[b]).compareTo(_peak(db, segments[a])));
    final kept = keep.take(_maxBursts).toSet();
    final bursts = <_Burst>[
      for (var i = 0; i < segments.length; i++)
        if (kept.contains(i))
          _burst(
            samples: hp,
            sampleRate: sampleRate,
            frame: frame,
            hop: hop,
            hopMs: hopMs,
            db: db,
            floorDb: floorDb,
            segment: segments[i],
            segmentIndex: i,
            total: total,
          ),
    ];
    final spectrum = _features(total, sampleRate / frame);

    final totalMs = samples.length * 1000 / sampleRate;
    final activeMs = activeFrames * hopMs;
    final activeRatio = totalMs <= 0 ? 0.0 : activeMs / totalMs;

    final classified = _classify(
      segments: segments,
      bursts: bursts,
      hopMs: hopMs,
      contrast: contrast,
      activeRatio: activeRatio,
      periodicity: periodicity,
      periodSec: periodSec,
      syllabic: syllabic,
    );

    final subEvents = classified.subEvents;
    var pitchSum = 0.0;
    var pitchWeight = 0.0;
    for (final b in bursts) {
      final w = _burstWeight(b, peakDb);
      pitchSum += (1 - b.jitter).clamp(0.0, 1.0) * w;
      pitchWeight += w;
    }

    return SleepChunkAnalysis(
      category: classified.category,
      confidence: classified.confidence,
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
      harmonicity: _pooled(bursts, peakDb, (b) => b.harmonicity),
      attackMs: bursts.isEmpty
          ? 0
          : (bursts.map((b) => b.attackSec).reduce(math.min) * 1000).round(),
      peakAmplitude: samples.fold(0.0, (a, v) => math.max(a, v.abs())),
      periodicity: periodicity,
      periodSec: periodSec,
      subEvents: subEvents,
      mixed: classified.mixed,
      margin: classified.margin,
      pitchStability: pitchWeight <= 0 ? 0 : (pitchSum / pitchWeight),
      clipped: clipped,
      bands: spectrum.bands,
    );
  }

  static double _pooled(
    List<_Burst> bursts,
    double loudestDb,
    double Function(_Burst b) pick,
  ) {
    var sum = 0.0;
    var weight = 0.0;
    for (final b in bursts) {
      final w = _burstWeight(b, loudestDb);
      sum += pick(b) * w;
      weight += w;
    }
    return weight <= 0 ? 0 : sum / weight;
  }

  static double _burstWeight(_Burst b, double loudestDb) =>
      math.sqrt(b.durSec.clamp(0.05, 3.0)) *
      math.pow(10, (b.peakDb - loudestDb) / 20);

  /// Runs of active frames with hysteresis, bridged across gaps up to
  /// [maxGap] frames and dropped when shorter than [minFrames].
  static List<(int, int)> _activeSegments(
    Float64List db,
    double startThr,
    double releaseThr,
    int maxGap,
    int minFrames,
  ) {
    final out = <(int, int)>[];
    int? start;
    var last = -1;
    var quiet = 0;
    void close() {
      final s = start;
      if (s != null && last - s + 1 >= minFrames) out.add((s, last));
      start = null;
      last = -1;
      quiet = 0;
    }

    for (var f = 0; f < db.length; f++) {
      if (start == null) {
        if (db[f] >= startThr) {
          start = f;
          last = f;
        }
        continue;
      }
      if (db[f] >= releaseThr) {
        last = f;
        quiet = 0;
        continue;
      }
      quiet++;
      if (quiet > maxGap) close();
    }
    close();
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

  /// Shape, spectrum and pitch of one burst; its frame spectra also go into
  /// [total] for the chunk-wide features.
  static _Burst _burst({
    required Float32List samples,
    required int sampleRate,
    required int frame,
    required int hop,
    required double hopMs,
    required Float64List db,
    required double floorDb,
    required (int, int) segment,
    required int segmentIndex,
    required Float64List total,
  }) {
    final (a, b) = segment;
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
    final decaySec = (decayEnd - peakFrame) * hopMs / 1000;
    final reachedDecay = db[decayEnd] <= peakDb - 15;

    final frames = [for (var f = a; f <= b; f++) f]
      ..sort((x, y) => db[y].compareTo(db[x]));
    final power = Float64List(frame ~/ 2);
    final buf = Float64List(frame);
    final spectrumFrames = frames.take(_spectrumFramesPerBurst).toList();
    var fluxSum = 0.0;
    var fluxCount = 0;
    var zcrSum = 0.0;
    var crestMax = 0.0;
    var crestEnergy = 0.0;
    var crestSamples = 0;
    Float64List? previous;
    for (final f in spectrumFrames) {
      final start = f * hop;
      for (var i = 0; i < frame; i++) {
        final idx = start + i;
        buf[i] = idx < samples.length ? samples[idx] : 0;
      }
      final spec = Fft.magnitudeSpectrum(buf, sampleRate);
      for (var i = 0; i < power.length; i++) {
        final p = spec.magnitudes[i] * spec.magnitudes[i];
        power[i] += p;
        total[i] += p;
      }
      if (previous != null) {
        var diff = 0.0;
        var base = 0.0;
        for (var i = 0; i < previous.length; i++) {
          final d = spec.magnitudes[i] - previous[i];
          if (d > 0) diff += d;
          base += previous[i];
        }
        if (base > 1e-12) fluxSum += diff / base;
        fluxCount++;
      }
      previous = Float64List.fromList(spec.magnitudes);

      var crossings = 0;
      var peak = 0.0;
      var energy = 0.0;
      for (var i = 0; i < frame; i++) {
        final v = buf[i];
        if (i > 0 && (v >= 0) != (buf[i - 1] >= 0)) crossings++;
        peak = math.max(peak, v.abs());
        energy += v * v;
      }
      zcrSum += crossings / frame;
      crestMax = math.max(crestMax, peak);
      crestEnergy += energy;
      crestSamples += frame;
    }
    final frameCount = math.max(1, spectrumFrames.length);
    final spectrum = _features(power, sampleRate / frame);

    final strength = <double>[];
    final pitch = <double>[];
    for (final f in frames.take(_pitchFramesPerBurst)) {
      final (r, hz) = _pitch(samples, f * hop, frame * 2, sampleRate);
      strength.add(r);
      if (r >= 0.3 && hz > 0) pitch.add(hz);
    }
    strength.sort();
    final pitchStrength = strength.isEmpty
        ? 0.0
        : strength[strength.length ~/ 2];
    // A random low-frequency signal still correlates a little at some lag.
    // Scale that floor away so only a clear periodic dip reads as voiced.
    final harmonicity = ((pitchStrength - 0.2) / 0.8).clamp(0.0, 1.0);
    double jitter = 0.5;
    var pitchHz = 0.0;
    if (pitch.isNotEmpty) {
      pitch.sort();
      pitchHz = pitch[pitch.length ~/ 2];
      if (pitch.length >= 2 && pitchHz > 0) {
        var dev = 0.0;
        for (final p in pitch) {
          dev += (p - pitchHz).abs();
        }
        jitter = (dev / pitch.length / pitchHz).clamp(0.0, 1.0);
      }
    }
    final rms = crestSamples <= 0 ? 0.0 : math.sqrt(crestEnergy / crestSamples);

    return _Burst(
      segmentIndex: segmentIndex,
      durSec: (b - a + 1) * hopMs / 1000,
      attackSec: attackSec,
      decaySec: decaySec,
      reachedDecay: reachedDecay,
      peakDb: peakDb,
      centroid: spectrum.centroid,
      lowRatio: spectrum.lowRatio,
      highRatio: spectrum.highRatio,
      flatness: spectrum.flatness,
      slope: spectrum.slope,
      bands: spectrum.bands,
      flux: fluxCount == 0 ? 0 : (fluxSum / fluxCount).clamp(0.0, 2.0),
      zcr: zcrSum / frameCount,
      crest: rms <= 0 ? 0 : crestMax / rms,
      harmonicity: harmonicity,
      pitchHz: pitchHz,
      jitter: jitter,
      flutter: _flutter(
        samples,
        a * hop,
        math.min(samples.length, (b + 1) * hop),
        sampleRate,
      ),
    );
  }

  static _Spectrum _features(Float64List power, double binHz) {
    final lo = math.max(1, (_bandLowHz / binHz).ceil());
    final hi = math.min(power.length - 1, (_bandHighHz / binHz).floor());
    if (hi <= lo) {
      return const _Spectrum(0, 0, 0, 0, 0, 0, []);
    }
    var total = 0.0, weighted = 0.0, low = 0.0, high = 0.0, best = 0.0;
    var dominant = 0.0;
    var logSum = 0.0, flatSum = 0.0;
    var flatBins = 0;
    var sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
    var slopeBins = 0;
    final bandPower = List<double>.filled(_bandCenters.length, 0);
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
      for (var b = 0; b < _bandCenters.length; b++) {
        final center = _bandCenters[b];
        if (hz >= center / math.sqrt2 && hz < center * math.sqrt2) {
          bandPower[b] += p;
          break;
        }
      }
      if (hz >= 100 && hz <= 6000) {
        logSum += math.log(p + 1e-20);
        flatSum += p;
        flatBins++;
        final x = math.log(hz) / math.ln2;
        final y = 10 * math.log(p + 1e-20) / math.ln10;
        sx += x;
        sy += y;
        sxx += x * x;
        sxy += x * y;
        slopeBins++;
      }
    }
    if (total <= 0) {
      return _Spectrum(0, 0, 0, 0, 0, 0, List<double>.filled(8, 0));
    }
    final flatness = flatBins == 0 || flatSum <= 0
        ? 0.0
        : math.exp(logSum / flatBins) / (flatSum / flatBins);
    final denom = slopeBins * sxx - sx * sx;
    final slope = slopeBins < 4 || denom.abs() < 1e-9
        ? 0.0
        : ((slopeBins * sxy - sx * sy) / denom).clamp(-60.0, 60.0);
    return _Spectrum(
      weighted / total,
      dominant,
      low / total,
      high / total,
      flatness,
      slope,
      [for (final p in bandPower) p / total],
    );
  }

  /// Pitch strength and frequency between 30 and 500 Hz (palate flutter up to
  /// voice) from the cumulative-mean-normalized difference of a decimated,
  /// pre-emphasized window (YIN). A clear first dip is the period; noise has
  /// no dip and scores near zero.
  static (double, double) _pitch(
    Float32List samples,
    int start,
    int length,
    int sampleRate,
  ) {
    final step = math.max(1, sampleRate ~/ 11025);
    final rate = sampleRate / step;
    final n = length ~/ step;
    if (n < 64) return (0, 0);
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
    final minLag = math.max(2, (rate / 500).floor());
    final maxLag = math.min(n - 2, (rate / 30).ceil());
    if (maxLag <= minLag) return (0, 0);

    final diff = Float64List(maxLag + 1);
    for (var lag = 1; lag <= maxLag; lag++) {
      var sum = 0.0;
      for (var i = 0; i + lag < n; i++) {
        final d = y[i] - y[i + lag];
        sum += d * d;
      }
      diff[lag] = sum;
    }
    final cmnd = Float64List(maxLag + 1);
    var running = 0.0;
    cmnd[0] = 1;
    for (var lag = 1; lag <= maxLag; lag++) {
      running += diff[lag];
      cmnd[lag] = running <= 1e-12 ? 1 : diff[lag] * lag / running;
    }

    var bestLag = -1;
    for (var lag = minLag; lag <= maxLag; lag++) {
      if (cmnd[lag] >= 0.2) continue;
      final lower = lag == minLag || cmnd[lag] <= cmnd[lag - 1];
      final upper = lag == maxLag || cmnd[lag] <= cmnd[lag + 1];
      if (lower && upper) {
        bestLag = lag;
        break;
      }
    }
    if (bestLag < 0) {
      var best = 2.0;
      for (var lag = minLag; lag <= maxLag; lag++) {
        if (cmnd[lag] < best) {
          best = cmnd[lag];
          bestLag = lag;
        }
      }
    }
    if (bestLag < 0) return (0, 0);
    final strength = (1 - cmnd[bestLag]).clamp(0.0, 1.0);
    return (strength, rate / bestLag);
  }

  /// Share of the 0.5 s low-frequency envelope that fluctuates between 20 and
  /// 60 Hz: palatal flutter gives snoring its roughness, rustling does not.
  static double _flutter(
    Float32List samples,
    int start,
    int end,
    int sampleRate,
  ) {
    if (end <= start) return 0;
    final window = math.max(8, (sampleRate * 0.002).round());
    final count = (end - start) ~/ window;
    if (count < 100) return 0;
    final take = math.min(256, count);
    final env = Float64List(256);
    var mean = 0.0;
    for (var i = 0; i < take; i++) {
      final base = start + i * window;
      var sum = 0.0;
      for (var k = 0; k < window; k++) {
        final idx = base + k;
        if (idx < end) {
          final v = samples[idx];
          sum += v * v;
        }
      }
      final v = math.sqrt(sum / window);
      env[i] = v;
      mean += v;
    }
    mean /= take;
    for (var i = 0; i < take; i++) {
      env[i] -= mean;
    }
    final spec = Fft.magnitudeSpectrum(env, (1 / 0.002).round());
    var flutter = 0.0;
    var total = 0.0;
    for (var i = 1; i < spec.magnitudes.length; i++) {
      final hz = i * spec.binHz;
      if (hz < 20 || hz > 400) continue;
      final p = spec.magnitudes[i] * spec.magnitudes[i];
      total += p;
      if (hz <= 60) flutter += p;
    }
    return total <= 0 ? 0 : (flutter / total).clamp(0.0, 1.0);
  }

  /// Rhythm of the night's events. Burst onsets are more reliable than the
  /// whole-chunk envelope, which only holds a few breathing cycles per chunk.
  static (double, double) _rhythm(
    List<(int, int)> segments,
    double hopMs,
    Float64List db,
    double floorDb,
  ) {
    if (segments.length >= 3) {
      final onsets = [for (final s in segments) s.$1 * hopMs / 1000];
      final best = _onsetPeriod(onsets);
      if (best.$1 > 0.35) return best;
    }
    return _periodicity(db, floorDb, hopMs, 1.2, 7.0);
  }

  /// Highest share of onsets that recur at a multiple of [period].
  static (double, double) _onsetPeriod(List<double> onsets) {
    final n = onsets.length;
    if (n < 3) return (0, 0);
    var bestScore = 0.0;
    var bestPeriod = 0.0;
    for (var period = 1.5; period <= 7.0; period += 0.05) {
      final tolerance = math.max(0.08, period * 0.06);
      var score = 0.0;
      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          final d = onsets[j] - onsets[i];
          if (d < period * 0.75 || d > 7.5) continue;
          final k = (d / period).round();
          if (k < 1) continue;
          final error = (d - k * period).abs();
          if (error <= tolerance) score += (1 - error / tolerance) / k;
        }
      }
      final normalized = score / math.max(1, n - 1);
      if (normalized > bestScore) {
        bestScore = normalized;
        bestPeriod = period;
      }
    }
    return (bestScore.clamp(0.0, 1.0), bestPeriod);
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
    if (maxLag <= minLag) return (0, 0);
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

  static _Classified _classify({
    required List<(int, int)> segments,
    required List<_Burst> bursts,
    required double hopMs,
    required double contrast,
    required double activeRatio,
    required double periodicity,
    required double periodSec,
    required double syllabic,
  }) {
    if (segments.isEmpty || (activeRatio > 0.8 && contrast < 15)) {
      return _Classified(
        category: SleepSoundCategory.steady,
        confidence: contrast < 10 ? 0.8 : 0.6,
        margin: 1,
        subEvents: const [],
      );
    }

    final bySegment = <int, List<_Burst>>{};
    for (final b in bursts) {
      bySegment.putIfAbsent(b.segmentIndex, () => []).add(b);
    }
    final loudest = bursts.fold(-180.0, (a, b) => math.max(a, b.peakDb));

    final raw = <int, Map<SleepSoundCategory, double>>{};
    var coughLike = 0;
    var snoreSum = 0.0;
    var snoreWeight = 0.0;
    for (var i = 0; i < segments.length; i++) {
      final list = bySegment[i] ?? const <_Burst>[];
      final scores = <SleepSoundCategory, double>{};
      var weightSum = 0.0;
      for (final b in list) {
        final w = _burstWeight(b, loudest);
        weightSum += w;
        final burstScores = _scoreBurst(b);
        burstScores.forEach((c, v) => scores[c] = (scores[c] ?? 0) + v * w);
        if ((burstScores[SleepSoundCategory.cough] ?? 0) >= 0.6) {
          coughLike++;
        }
      }
      if (weightSum > 0) {
        scores.updateAll((_, v) => v / weightSum);
      }
      raw[i] = scores;
      final w = segments[i].$2 - segments[i].$1 + 1.0;
      snoreSum += (scores[SleepSoundCategory.snore] ?? 0) * w;
      snoreWeight += w;
    }

    final boost = <SleepSoundCategory, double>{};
    final rhythmic =
        periodicity > 0.35 &&
        periodSec >= 1.5 &&
        periodSec <= 8 &&
        segments.length >= 3;
    // Breathing rhythm only confirms snoring when the bursts are also voiced,
    // otherwise heavy breathing or rhythmic rustling would pass for it.
    final snoreEvidence = snoreWeight <= 0 ? 0.0 : snoreSum / snoreWeight;
    if (rhythmic && snoreEvidence >= 0.3) {
      boost[SleepSoundCategory.snore] = 0.25;
    }
    if (syllabic > 0.25) boost[SleepSoundCategory.speech] = 0.2;
    if (coughLike >= 2) boost[SleepSoundCategory.cough] = 0.1;
    if (!rhythmic) boost[SleepSoundCategory.movement] = 0.05;

    final subs = <SleepSubEvent>[];
    for (var i = 0; i < segments.length; i++) {
      final scores = {...raw[i]!};
      boost.forEach((c, v) => scores[c] = (scores[c] ?? 0) + v);
      final entries = scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      var topCategory = SleepSoundCategory.other;
      var topScore = 0.0;
      var secondScore = 0.0;
      if (entries.isNotEmpty) {
        topCategory = entries.first.key;
        topScore = entries.first.value;
        if (entries.length > 1) secondScore = entries[1].value;
      }
      if (topScore < 0.35) {
        topCategory = SleepSoundCategory.other;
      }
      final confidence = topScore < 0.35
          ? topScore.clamp(0.0, 0.3)
          : _subConfidence(topScore, secondScore, topCategory);
      final s = segments[i];
      var peakDb = _zeroDb;
      for (final b in bySegment[i] ?? const <_Burst>[]) {
        peakDb = math.max(peakDb, b.peakDb);
      }
      subs.add(
        SleepSubEvent(
          startMs: (s.$1 * hopMs).round(),
          endMs: ((s.$2 + 1) * hopMs).round(),
          category: topCategory,
          confidence: confidence,
          peakDb: peakDb,
        ),
      );
    }
    final merged = _mergeSubEvents(subs);

    final durations = <SleepSoundCategory, int>{};
    for (final s in merged) {
      durations[s.category] = (durations[s.category] ?? 0) + s.durationMs;
    }
    final totalMs = durations.values.fold<int>(0, (a, b) => a + b);
    if (totalMs <= 0) {
      return const _Classified(
        category: SleepSoundCategory.other,
        confidence: 0.2,
        margin: 0,
        subEvents: [],
      );
    }
    final ranked = durations.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = ranked.first;
    final share = top.value / totalMs;
    final secondShare = ranked.length > 1 ? ranked[1].value / totalMs : 0.0;

    var weightedConfidence = 0.0;
    for (final s in merged) {
      weightedConfidence += s.confidence * s.durationMs;
    }
    weightedConfidence /= totalMs;
    final confidence = (weightedConfidence * (0.55 + 0.45 * share)).clamp(
      0.0,
      1.0,
    );

    return _Classified(
      category: share < 0.45 ? SleepSoundCategory.other : top.key,
      confidence: share < 0.45 ? math.min(confidence, 0.4) : confidence,
      mixed: secondShare >= 0.25 && share < 0.8,
      margin: (share - secondShare).clamp(0.0, 1.0),
      subEvents: merged,
    );
  }

  static double _subConfidence(
    double top,
    double second,
    SleepSoundCategory category,
  ) {
    final max = _maxScore[category] ?? 1.0;
    final normalized = (top / max).clamp(0.0, 1.0);
    final margin = ((top - second) / 0.2).clamp(0.0, 1.0);
    return (0.5 * normalized + 0.5 * margin).clamp(0.05, 1.0);
  }

  /// Joins neighbouring runs of the same sound so the timeline does not split
  /// one snore into a dozen bars.
  static List<SleepSubEvent> _mergeSubEvents(List<SleepSubEvent> events) {
    if (events.isEmpty) return events;
    final out = <SleepSubEvent>[];
    for (final e in events) {
      final last = out.isEmpty ? null : out.last;
      if (last != null &&
          last.category == e.category &&
          e.startMs - last.endMs <= 500) {
        final a = last.durationMs;
        final b = e.durationMs;
        final total = math.max(1, a + b);
        out[out.length - 1] = SleepSubEvent(
          startMs: last.startMs,
          endMs: e.endMs,
          category: last.category,
          confidence: (last.confidence * a + e.confidence * b) / total,
          peakDb: math.max(last.peakDb, e.peakDb),
        );
      } else {
        out.add(e);
      }
    }
    return out;
  }

  static Map<SleepSoundCategory, double> _scoreBurst(_Burst b) {
    final explosive = b.attackSec <= 0.05;
    final swelling = b.attackSec >= 0.15;
    final noisy = b.harmonicity < 0.3;
    final voiced = b.harmonicity >= 0.5;
    final pitched = b.pitchHz >= 40 && b.pitchHz <= 350;
    final stable = b.jitter < 0.035;
    final bright = b.highRatio >= 0.08 || b.centroid >= 900;
    final lowShare = _bandShare(b, 0, 2);
    final midShare = _bandShare(b, 2, 4);

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
    if (b.zcr > 0.12) cough += 0.1;
    if (b.highRatio > 0.2) cough += 0.1;

    var snore = 0.0;
    if (voiced && pitched) {
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
    if (lowShare >= 0.55) snore += 0.15;
    if (pitched && stable) snore += 0.15;
    if (b.flutter >= 0.12 && b.harmonicity >= 0.35) snore += 0.25;

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
    if (b.zcr >= 0.2) movement += 0.15;
    if (b.crest >= 6) movement += 0.1;

    var speech = 0.0;
    if (voiced) speech += 0.25;
    if (b.centroid >= 350 && b.centroid <= 3000) speech += 0.15;
    if (pitched && b.pitchHz >= 75 && b.pitchHz <= 350) speech += 0.15;
    if (b.durSec >= 0.3) speech += 0.05;
    if (b.jitter >= 0.04) speech += 0.2;
    if (midShare >= 0.35) speech += 0.1;
    if (b.flux >= 0.4) speech += 0.1;

    return {
      SleepSoundCategory.impulse: impulse,
      SleepSoundCategory.cough: cough,
      SleepSoundCategory.snore: snore,
      SleepSoundCategory.movement: movement,
      SleepSoundCategory.speech: speech,
    };
  }

  static double _bandShare(_Burst b, int from, int to) {
    if (b.bands.length <= to) return 0;
    var sum = 0.0;
    for (var i = from; i < to; i++) {
      sum += b.bands[i];
    }
    return sum;
  }

  static const Map<SleepSoundCategory, double> _maxScore = {
    SleepSoundCategory.impulse: 0.9,
    SleepSoundCategory.cough: 1.2,
    SleepSoundCategory.snore: 1.3,
    SleepSoundCategory.movement: 1.05,
    SleepSoundCategory.speech: 1.0,
  };

  static const List<double> _bandCenters = [
    63,
    125,
    250,
    500,
    1000,
    2000,
    4000,
    8000,
  ];

  static const double _zeroDb = -90;

  /// One-pole high-pass at [_highPassHz], removing DC and rumble below the
  /// phone microphone's useful range.
  static Float32List _highPass(Float32List input, int sampleRate) {
    final dt = 1 / sampleRate;
    final rc = 1 / (2 * math.pi * _highPassHz);
    final a = rc / (rc + dt);
    final out = Float32List(input.length);
    var prevIn = 0.0;
    var prevOut = 0.0;
    for (var i = 0; i < input.length; i++) {
      final x = input[i];
      final y = a * (prevOut + x - prevIn);
      out[i] = y;
      prevIn = x;
      prevOut = y;
    }
    return out;
  }

  static double _clippedFraction(Float32List samples) {
    if (samples.isEmpty) return 0;
    var clipped = 0;
    for (final s in samples) {
      if (s.abs() >= 0.999) clipped++;
    }
    return clipped / samples.length;
  }

  static Float64List _median3(Float64List values) {
    final out = Float64List(values.length);
    for (var i = 0; i < values.length; i++) {
      final a = values[i];
      final b = i == 0 ? a : values[i - 1];
      final c = i + 1 >= values.length ? a : values[i + 1];
      out[i] = math.max(math.min(a, b), math.min(math.max(a, b), c));
    }
    return out;
  }

  static SleepChunkAnalysis _empty() => const SleepChunkAnalysis(
    category: SleepSoundCategory.steady,
    confidence: 0,
    levelDb: -90,
    floorDb: -90,
    activeMs: 0,
    firstActiveMs: 0,
    lastActiveMs: 0,
    loudestMs: 0,
    bursts: 0,
    centroidHz: 0,
    dominantHz: 0,
    lowRatio: 0,
    flatness: 0,
    periodicity: 0,
    periodSec: 0,
  );
}

class _Classified {
  const _Classified({
    required this.category,
    required this.confidence,
    required this.margin,
    required this.subEvents,
    this.mixed = false,
  });

  final SleepSoundCategory category;
  final double confidence;
  final bool mixed;
  final double margin;
  final List<SleepSubEvent> subEvents;
}

class _Burst {
  const _Burst({
    required this.segmentIndex,
    required this.durSec,
    required this.attackSec,
    required this.decaySec,
    required this.reachedDecay,
    required this.peakDb,
    required this.centroid,
    required this.lowRatio,
    required this.highRatio,
    required this.flatness,
    required this.slope,
    required this.bands,
    required this.flux,
    required this.zcr,
    required this.crest,
    required this.harmonicity,
    required this.pitchHz,
    required this.jitter,
    required this.flutter,
  });

  final int segmentIndex;
  final double durSec;
  final double attackSec;
  final double decaySec;
  final bool reachedDecay;
  final double peakDb;
  final double centroid;
  final double lowRatio;
  final double highRatio;
  final double flatness;
  final double slope;
  final List<double> bands;
  final double flux;
  final double zcr;
  final double crest;
  final double harmonicity;
  final double pitchHz;
  final double jitter;
  final double flutter;
}

class _Spectrum {
  const _Spectrum(
    this.centroid,
    this.dominant,
    this.lowRatio,
    this.highRatio,
    this.flatness,
    this.slope,
    this.bands,
  );

  final double centroid;
  final double dominant;
  final double lowRatio;
  final double highRatio;
  final double flatness;
  final double slope;
  final List<double> bands;
}
