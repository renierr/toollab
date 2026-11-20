class DayAstronomy {
  const DayAstronomy({
    required this.date,
    this.sunrise,
    this.sunset,
    this.moonrise,
    this.moonset,
    this.moonPhase,
    this.iconCode,
  });

  factory DayAstronomy.fromJson(Map<String, dynamic> json) {
    DateTime? time(String key) {
      final v = json[key];
      return v is num
          ? DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true)
          : null;
    }

    final icon = (json['icon'] as num?)?.toInt();
    return DayAstronomy(
      date: DateTime.parse(json['dayDate'] as String),
      sunrise: time('sunriseOnThisDay') ?? time('sunrise'),
      sunset: time('sunsetOnThisDay') ?? time('sunset'),
      moonrise: time('moonriseOnThisDay'),
      moonset: time('moonsetOnThisDay'),
      moonPhase: (json['moonPhase'] as num?)?.toInt(),
      iconCode: icon == _missing ? null : icon,
    );
  }

  static const int _missing = 32767;

  final DateTime date;
  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime? moonrise;
  final DateTime? moonset;

  /// DWD moon phase index 0–7, 0 = new moon.
  final int? moonPhase;
  final int? iconCode;
}
