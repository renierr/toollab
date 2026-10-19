import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'audio/db_scale.dart';
import 'audio/sleep_chunk_analyzer.dart';

// UTC on disk keeps chunk sync clocks equal across device time zones; older
// files without a zone suffix still parse as local time.
String _iso(DateTime t) => t.toUtc().toIso8601String();
DateTime _parse(Object? raw) => DateTime.parse(raw as String).toLocal();

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
  final double peakAmplitude;

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
