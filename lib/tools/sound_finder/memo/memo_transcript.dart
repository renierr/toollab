import 'dart:convert';
import 'dart:io';

/// One timed phrase of a transcript.
class MemoTranscriptSegment {
  final Duration start;
  final Duration end;
  final String text;

  const MemoTranscriptSegment({
    required this.start,
    required this.end,
    required this.text,
  });

  factory MemoTranscriptSegment.fromJson(Map<String, dynamic> j) =>
      MemoTranscriptSegment(
        start: Duration(milliseconds: (j['start'] as num).toInt()),
        end: Duration(milliseconds: (j['end'] as num).toInt()),
        text: j['text'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'start': start.inMilliseconds,
    'end': end.inMilliseconds,
    'text': text,
  };
}

/// Transcript of a memo, stored as a JSON file next to the audio.
class MemoTranscript {
  final String model;
  final String language;
  final DateTime created;
  final List<MemoTranscriptSegment> segments;
  final String? summary;

  const MemoTranscript({
    required this.model,
    required this.language,
    required this.created,
    required this.segments,
    this.summary,
  });

  String get text => segments.map((s) => s.text).join(' ').trim();

  bool get isEmpty => text.isEmpty;

  MemoTranscript withSummary(String? summary) => MemoTranscript(
    model: model,
    language: language,
    created: created,
    segments: segments,
    summary: summary,
  );

  factory MemoTranscript.fromJson(Map<String, dynamic> j) => MemoTranscript(
    model: j['model'] as String? ?? '',
    language: j['language'] as String? ?? '',
    created: DateTime.tryParse(j['created'] as String? ?? '') ?? DateTime.now(),
    segments: [
      for (final s in (j['segments'] as List? ?? const []))
        MemoTranscriptSegment.fromJson((s as Map).cast<String, dynamic>()),
    ],
    summary: j['summary'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'model': model,
    'language': language,
    'created': created.toIso8601String(),
    'segments': [for (final s in segments) s.toJson()],
    if (summary != null) 'summary': summary,
  };

  /// Plain text with `[mm:ss]` stamps, for copying, sharing and notes.
  String toPlainText({bool timestamps = true}) {
    if (!timestamps) return text;
    return segments
        .map((s) => '[${_clock(s.start)}] ${s.text.trim()}')
        .join('\n');
  }

  static String _clock(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  static String sidecarPath(String audioPath) => '$audioPath.transcript.json';

  static Future<MemoTranscript?> load(String audioPath) async {
    final file = File(sidecarPath(audioPath));
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString());
      return MemoTranscript.fromJson((json as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String audioPath) =>
      File(sidecarPath(audioPath)).writeAsString(jsonEncode(toJson()));

  static Future<void> delete(String audioPath) async {
    final file = File(sidecarPath(audioPath));
    if (await file.exists()) await file.delete();
  }

  static Future<void> move(String fromAudio, String toAudio) async {
    final file = File(sidecarPath(fromAudio));
    if (await file.exists()) await file.rename(sidecarPath(toAudio));
  }
}
