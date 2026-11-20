class WeatherWarning {
  const WeatherWarning({
    required this.id,
    required this.type,
    required this.level,
    required this.start,
    this.end,
    required this.event,
    required this.headline,
    required this.description,
    required this.instruction,
  });

  factory WeatherWarning.fromJson(Map<String, dynamic> json) => WeatherWarning(
    id: json['warnId'] as String? ?? '',
    type: (json['type'] as num?)?.toInt() ?? 0,
    level: (json['level'] as num?)?.toInt() ?? 0,
    start: DateTime.fromMillisecondsSinceEpoch(
      (json['start'] as num).toInt(),
      isUtc: true,
    ),
    end: json['end'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (json['end'] as num).toInt(),
            isUtc: true,
          ),
    event: json['event'] as String? ?? '',
    headline: json['headline'] as String? ?? '',
    description:
        json['description'] as String? ??
        json['descriptionText'] as String? ??
        '',
    instruction: json['instruction'] as String? ?? '',
  );

  final String id;
  final int type;

  /// DWD level: 1 weather notice … 4 extreme.
  final int level;
  final DateTime start;
  final DateTime? end;
  final String event;
  final String headline;
  final String description;
  final String instruction;

  bool isActiveAt(DateTime time) =>
      !time.isBefore(start) && (end == null || time.isBefore(end!));
}
