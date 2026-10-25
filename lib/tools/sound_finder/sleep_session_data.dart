import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'audio/db_scale.dart';
import 'audio/sleep_chunk_analyzer.dart';

// UTC on disk keeps chunk sync clocks equal across device time zones; older
// files without a zone suffix still parse as local time.
String _iso(DateTime t) => t.toUtc().toIso8601String();
DateTime _parse(Object? raw) => DateTime.parse(raw as String).toLocal();

/// Loudness measured while recording one chunk, kept for silence too, so the
/// night timeline has a continuous level line and the analyzer gets a real
/// room-floor prior even when no file was written.
class SleepLevelSample {
  const SleepLevelSample({
    required this.at,
    required this.peakDb,
    required this.rmsDb,
  });

  final DateTime at;
  final double peakDb;
  final double rmsDb;

  List<Object> toJson() => [
    at.millisecondsSinceEpoch,
    double.parse(peakDb.toStringAsFixed(1)),
    double.parse(rmsDb.toStringAsFixed(1)),
  ];

  factory SleepLevelSample.fromJson(Object? raw) {
    if (raw is List && raw.length >= 3) {
      return SleepLevelSample(
        at: DateTime.fromMillisecondsSinceEpoch((raw[0] as num).toInt()),
        peakDb: (raw[1] as num).toDouble(),
        rmsDb: (raw[2] as num).toDouble(),
      );
    }
    return SleepLevelSample(
      at: DateTime.fromMillisecondsSinceEpoch(0),
      peakDb: -90,
      rmsDb: -90,
    );
  }
}

/// A sound on the session timeline, already joined across chunk boundaries.
class SleepSoundSpan {
  const SleepSoundSpan({
    required this.start,
    required this.end,
    required this.category,
    required this.confidence,
    required this.peakDb,
  });

  final DateTime start;
  final DateTime end;
  final SleepSoundCategory category;
  final double confidence;
  final double peakDb;

  Duration get duration => end.difference(start);
}

/// A single captured chunk inside a sleep session.
class SleepEvent {
  SleepEvent({
    required this.fileName,
    required this.startedAt,
    required this.endedAt,
    required this.peakAmplitude,
    this.classification = 'sound',
    this.annotation,
    this.analysis,
  });

  /// Bare file name; the session directory resolves it, so a session pulled
  /// onto another device keeps working.
  final String fileName;
  final DateTime startedAt;
  final DateTime endedAt;

  /// Set while recording; analysis re-measures it from the file, which also
  /// repairs sessions rebuilt from file names alone.
  double peakAmplitude;

  /// Level bucket assigned while recording: loud, sound or faint.
  final String classification;
  String? annotation;
  SleepChunkAnalysis? analysis;

  Duration get duration => endedAt.difference(startedAt);

  double get peakDb => ampToDb(peakAmplitude);

  Map<String, dynamic> toJson() => {
    'file': fileName,
    'startedAt': _iso(startedAt),
    'endedAt': _iso(endedAt),
    'peakAmplitude': peakAmplitude,
    'classification': classification,
    'annotation': annotation,
    if (analysis != null) 'analysis': analysis!.toJson(),
  };

  factory SleepEvent.fromJson(Map<String, dynamic> json) {
    final raw = json['analysis'];
    return SleepEvent(
      fileName: (json['file'] as String).split(RegExp(r'[\\/]')).last,
      startedAt: _parse(json['startedAt']),
      endedAt: _parse(json['endedAt']),
      peakAmplitude: (json['peakAmplitude'] as num).toDouble(),
      classification: json['classification'] as String? ?? 'sound',
      annotation: json['annotation'] as String?,
      analysis: raw is Map<String, dynamic>
          ? SleepChunkAnalysis.fromJson(raw)
          : null,
    );
  }
}

/// Aggregate metadata for one sleep session.
class SleepSessionData {
  SleepSessionData({
    required this.path,
    required this.startedAt,
    required this.endedAt,
    required this.targetMinutes,
    required this.threshold,
    required this.adaptiveThreshold,
    required this.events,
    this.levels = const [],
    int? updatedAt,
    this.analysisVersion = 0,
  }) : updatedAt = updatedAt ?? endedAt.millisecondsSinceEpoch;

  final String path;
  final DateTime startedAt;
  final DateTime endedAt;
  final int targetMinutes;
  final double threshold;
  final bool adaptiveThreshold;
  final List<SleepEvent> events;

  /// One loudness sample per recorded chunk, quiet ones included.
  final List<SleepLevelSample> levels;

  /// Sync clock in epoch milliseconds; bumped on every local edit.
  int updatedAt;

  /// [SleepChunkAnalyzer.version] the events were last analyzed with.
  int analysisVersion;

  String get id => path.split(RegExp(r'[\\/]')).last;

  bool get isAnalyzed =>
      events.isEmpty || analysisVersion >= SleepChunkAnalyzer.version;

  File fileFor(SleepEvent event) => File('$path/${event.fileName}');

  Duration get duration => endedAt.difference(startedAt);

  Duration get recordedDuration =>
      events.fold(Duration.zero, (a, e) => a + e.duration);

  double get avgPeakDb {
    if (events.isEmpty) return silenceDb;
    final sum = events.fold<double>(0, (a, e) => a + e.peakDb);
    return sum / events.length;
  }

  double get loudestDb {
    if (events.isEmpty) return silenceDb;
    return events.map((e) => e.peakDb).reduce(math.max);
  }

  /// Quiet-room prior for the analyzer: the 20th percentile of the chunk RMS
  /// levels, quiet chunks included. Null for sessions recorded before levels
  /// were stored.
  double? get noiseFloorDb {
    final values = [
      for (final l in levels)
        if (l.rmsDb > silenceDb) l.rmsDb,
    ]..sort();
    if (values.length < 4) return null;
    return values[(values.length * 0.2).floor()];
  }

  /// Every sound in the session, joined across chunk boundaries so a snore
  /// train or a cough fit is one span instead of two chunk-sized pieces.
  List<SleepSoundSpan> get soundSpans {
    final raw = <SleepSoundSpan>[];
    for (final e in events) {
      final a = e.analysis;
      if (a == null) continue;
      if (a.subEvents.isEmpty) {
        raw.add(
          SleepSoundSpan(
            start: e.startedAt.add(Duration(milliseconds: a.firstActiveMs)),
            end: e.startedAt.add(Duration(milliseconds: a.lastActiveMs)),
            category: a.category,
            confidence: a.confidence,
            peakDb: e.peakDb,
          ),
        );
        continue;
      }
      for (final s in a.subEvents) {
        raw.add(
          SleepSoundSpan(
            start: e.startedAt.add(Duration(milliseconds: s.startMs)),
            end: e.startedAt.add(Duration(milliseconds: s.endMs)),
            category: s.category,
            confidence: s.confidence,
            peakDb: s.peakDb,
          ),
        );
      }
    }
    raw.sort((a, b) => a.start.compareTo(b.start));

    final spans = <SleepSoundSpan>[];
    for (final span in raw) {
      if (!span.end.isAfter(span.start)) continue;
      final last = spans.isEmpty ? null : spans.last;
      if (last != null &&
          last.category == span.category &&
          span.start.difference(last.end) <=
              const Duration(milliseconds: 350)) {
        spans[spans.length - 1] = SleepSoundSpan(
          start: last.start,
          end: span.end.isAfter(last.end) ? span.end : last.end,
          category: last.category,
          confidence: (last.confidence + span.confidence) / 2,
          peakDb: math.max(last.peakDb, span.peakDb),
        );
        continue;
      }
      spans.add(span);
    }
    return spans;
  }

  /// Time each sound covers on the night, after cross-chunk merging.
  Map<SleepSoundCategory, Duration> get soundDurations {
    final out = <SleepSoundCategory, Duration>{};
    for (final s in soundSpans) {
      out[s.category] = (out[s.category] ?? Duration.zero) + s.duration;
    }
    return out;
  }

  File get jsonFile => File('$path/session.json');

  Map<String, dynamic> toJson() => {
    'startedAt': _iso(startedAt),
    'endedAt': _iso(endedAt),
    'targetMinutes': targetMinutes,
    'threshold': threshold,
    'adaptiveThreshold': adaptiveThreshold,
    'updatedAt': updatedAt,
    'analysisVersion': analysisVersion,
    'events': events.map((e) => e.toJson()).toList(),
    if (levels.isNotEmpty) 'levels': [for (final l in levels) l.toJson()],
  };

  /// Persists the session; [touch] advances [updatedAt] so sync pushes it.
  Future<void> save({bool touch = true}) async {
    if (touch) updatedAt = DateTime.now().millisecondsSinceEpoch;
    await Directory(path).create(recursive: true);
    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(toJson()),
    );
  }

  static SleepSessionData fromJson(String path, Map<String, dynamic> json) {
    final events =
        (json['events'] as List? ?? [])
            .map((e) => SleepEvent.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return SleepSessionData(
      path: path,
      startedAt: _parse(json['startedAt']),
      endedAt: _parse(json['endedAt']),
      targetMinutes: (json['targetMinutes'] as num?)?.toInt() ?? 0,
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.005,
      adaptiveThreshold: json['adaptiveThreshold'] as bool? ?? false,
      events: events,
      levels: [
        for (final raw in (json['levels'] as List? ?? const []))
          SleepLevelSample.fromJson(raw),
      ],
      updatedAt: (json['updatedAt'] as num?)?.toInt(),
      analysisVersion: (json['analysisVersion'] as num?)?.toInt() ?? 0,
    );
  }

  static Future<SleepSessionData?> load(String path) async {
    final file = File('$path/session.json');
    if (!await file.exists()) return null;
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return fromJson(path, json);
    } catch (_) {
      return null;
    }
  }
}
