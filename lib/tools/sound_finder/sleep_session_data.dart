import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// A single captured chunk inside a sleep session.
class SleepEvent {
  SleepEvent({
    required this.file,
    required this.startedAt,
    required this.endedAt,
    required this.peakAmplitude,
    this.classification = 'sound',
    this.annotation,
  });

  final String file;
  final DateTime startedAt;
  final DateTime endedAt;
  final double peakAmplitude;
  final String classification;
  String? annotation;

  double get peakDb {
    if (peakAmplitude <= 0) return -90;
    return 20 * math.log(peakAmplitude) / math.ln10;
  }

  Map<String, dynamic> toJson() => {
        'file': file,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'peakAmplitude': peakAmplitude,
        'classification': classification,
        'annotation': annotation,
      };

  factory SleepEvent.fromJson(Map<String, dynamic> json) => SleepEvent(
        file: json['file'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: DateTime.parse(json['endedAt'] as String),
        peakAmplitude: (json['peakAmplitude'] as num).toDouble(),
        classification: json['classification'] as String? ?? 'sound',
        annotation: json['annotation'] as String?,
      );
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
  });

  final String path;
  final DateTime startedAt;
  final DateTime endedAt;
  final int targetMinutes;
  final double threshold;
  final bool adaptiveThreshold;
  final List<SleepEvent> events;

  int get chunkCount => events.length;
  double get avgPeakDb {
    if (events.isEmpty) return -90;
    final sum = events.fold<double>(0, (a, e) => a + _ampToDb(e.peakAmplitude));
    return sum / events.length;
  }

  double get loudestDb {
    if (events.isEmpty) return -90;
    return events
        .map((e) => _ampToDb(e.peakAmplitude))
        .reduce((a, b) => a > b ? a : b);
  }

  File get jsonFile => File('$path/session.json');

  Future<void> save() async {
    final data = {
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'targetMinutes': targetMinutes,
      'threshold': threshold,
      'adaptiveThreshold': adaptiveThreshold,
      'events': events.map((e) => e.toJson()).toList(),
    };
    await jsonFile.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  static Future<SleepSessionData?> load(String path) async {
    final file = File('$path/session.json');
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final events = (json['events'] as List? ?? [])
          .map((e) => SleepEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      return SleepSessionData(
        path: path,
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: DateTime.parse(json['endedAt'] as String),
        targetMinutes: json['targetMinutes'] as int? ?? 0,
        threshold: (json['threshold'] as num?)?.toDouble() ?? 0.005,
        adaptiveThreshold: json['adaptiveThreshold'] as bool? ?? false,
        events: events,
      );
    } catch (_) {
      return null;
    }
  }

  static double _ampToDb(double amp) {
    if (amp <= 0) return -90;
    return 20 * math.log(amp) / math.ln10;
  }
}
