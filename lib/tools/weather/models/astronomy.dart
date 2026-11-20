import 'dart:math' as math;

class MoonState {
  const MoonState(this.age, this.illumination);

  static const double synodicMonth = 29.530588853;

  /// Days since new moon.
  final double age;

  /// Lit fraction 0–1.
  final double illumination;

  bool get isWaxing => age < synodicMonth / 2;

  /// 0 new … 4 full … 7 waning crescent.
  int get phaseIndex => ((age / synodicMonth) * 8 + 0.5).floor() % 8;

  static MoonState at(DateTime time) {
    final reference = DateTime.utc(2000, 1, 6, 18, 14);
    final days = time.toUtc().difference(reference).inSeconds / 86400;
    final age = days % synodicMonth;
    final illumination = (1 - math.cos(2 * math.pi * age / synodicMonth)) / 2;
    return MoonState(age, illumination);
  }
}

/// NOAA sunrise equation; used when the DWD day summary is missing.
class SunTimes {
  const SunTimes(this.sunrise, this.sunset);

  final DateTime? sunrise;
  final DateTime? sunset;

  static SunTimes of(DateTime date, double latitude, double longitude) {
    double rad(double d) => d * math.pi / 180;
    double deg(double r) => r * 180 / math.pi;
    final dayOfYear =
        DateTime.utc(
          date.year,
          date.month,
          date.day,
        ).difference(DateTime.utc(date.year)).inDays +
        1;
    final gamma = 2 * math.pi / 365 * (dayOfYear - 1);
    final eqTime =
        229.18 *
        (0.000075 +
            0.001868 * math.cos(gamma) -
            0.032077 * math.sin(gamma) -
            0.014615 * math.cos(2 * gamma) -
            0.040849 * math.sin(2 * gamma));
    final decl =
        0.006918 -
        0.399912 * math.cos(gamma) +
        0.070257 * math.sin(gamma) -
        0.006758 * math.cos(2 * gamma) +
        0.000907 * math.sin(2 * gamma) -
        0.002697 * math.cos(3 * gamma) +
        0.00148 * math.sin(3 * gamma);
    final cosHa =
        math.cos(rad(90.833)) / (math.cos(rad(latitude)) * math.cos(decl)) -
        math.tan(rad(latitude)) * math.tan(decl);
    if (cosHa.abs() > 1) return const SunTimes(null, null);
    final ha = deg(math.acos(cosHa));
    final midnight = DateTime.utc(date.year, date.month, date.day);
    DateTime at(double minutes) =>
        midnight.add(Duration(seconds: (minutes * 60).round()));
    return SunTimes(
      at(720 - 4 * (longitude + ha) - eqTime),
      at(720 - 4 * (longitude - ha) - eqTime),
    );
  }

  bool isDayAt(DateTime time) {
    final rise = sunrise;
    final set = sunset;
    if (rise == null || set == null) return true;
    return time.isAfter(rise) && time.isBefore(set);
  }
}
