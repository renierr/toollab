import 'dart:math' as math;

/// Output shapes for date/time rendering. All ISO-ordered (YYYY-MM-DD).
enum DateStyle {
  /// `2026-06-16`
  dateOnly,

  /// `2026-06-16 14:30`
  dateAndTime,

  /// `2026-06-16 14:30:05`
  dateTimeSeconds,
}

class FormatHelper {
  FormatHelper._();

  static String fileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = math
        .min((math.log(bytes) / math.log(1024)).floor(), suffixes.length - 1)
        .toInt();
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Format a [DateTime] using the unified ISO-ordered [style].
  static String dateTime(
    DateTime date, {
    DateStyle style = DateStyle.dateAndTime,
  }) {
    final year = date.year.toString().padLeft(4, '0');
    final month = _two(date.month);
    final day = _two(date.day);
    final dateStr = '$year-$month-$day';
    if (style == DateStyle.dateOnly) return dateStr;

    final time = '${_two(date.hour)}:${_two(date.minute)}';
    if (style == DateStyle.dateAndTime) return '$dateStr $time';

    return '$dateStr $time:${_two(date.second)}';
  }

  /// Format an epoch-millisecond timestamp. Returns [placeholder] when the
  /// timestamp is null or zero.
  static String epoch(
    int? timestampMs, {
    DateStyle style = DateStyle.dateAndTime,
    String placeholder = '',
  }) {
    if (timestampMs == null || timestampMs == 0) return placeholder;
    return dateTime(
      DateTime.fromMillisecondsSinceEpoch(timestampMs),
      style: style,
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
