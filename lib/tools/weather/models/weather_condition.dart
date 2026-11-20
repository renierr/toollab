enum WeatherCondition {
  clear,
  mostlyClear,
  partlyCloudy,
  cloudy,
  overcast,
  fog,
  drizzle,
  freezingDrizzle,
  lightRain,
  rain,
  heavyRain,
  freezingRain,
  sleet,
  lightSnow,
  snow,
  heavySnow,
  hail,
  rainShower,
  sleetShower,
  snowShower,
  thunderstorm;

  bool get isPrecipitation => index >= drizzle.index;

  bool get isSnowy =>
      this == lightSnow ||
      this == snow ||
      this == heavySnow ||
      this == snowShower;

  /// Maps a WMO present-weather code as used by MOSMIX `ww`; codes 0–3 only
  /// describe cloud development, so cloud cover decides the sky state.
  static WeatherCondition fromWw(int? ww, {double? cloudCover}) {
    if (ww == null || ww < 4) return fromCloudCover(cloudCover);
    return switch (ww) {
      >= 95 => thunderstorm,
      85 || 86 => snowShower,
      83 || 84 => sleetShower,
      >= 80 && <= 82 => rainShower,
      >= 71 && <= 79 => switch (ww) {
        71 => lightSnow,
        75 => heavySnow,
        _ => snow,
      },
      68 || 69 => sleet,
      66 || 67 => freezingRain,
      61 => lightRain,
      63 => rain,
      >= 64 && <= 65 => heavyRain,
      >= 60 && <= 62 => lightRain,
      56 || 57 => freezingDrizzle,
      >= 50 && <= 59 => drizzle,
      >= 40 && <= 49 => fog,
      _ => fromCloudCover(cloudCover),
    };
  }

  static WeatherCondition fromCloudCover(double? percent) {
    if (percent == null) return partlyCloudy;
    if (percent < 12.5) return clear;
    if (percent < 37.5) return mostlyClear;
    if (percent < 62.5) return partlyCloudy;
    if (percent < 87.5) return cloudy;
    return overcast;
  }

  /// Maps the DWD icon / POI `present_weather` table (1–31).
  static WeatherCondition? fromDwdCode(int? code) => switch (code) {
    1 => clear,
    2 => partlyCloudy,
    3 => cloudy,
    4 => overcast,
    5 || 6 => fog,
    7 => lightRain,
    8 => rain,
    9 => heavyRain,
    10 || 11 => freezingRain,
    12 || 13 => sleet,
    14 => lightSnow,
    15 => snow,
    16 => heavySnow,
    17 => hail,
    18 || 19 => rainShower,
    20 || 21 => sleetShower,
    22 || 23 => snowShower,
    24 || 25 => hail,
    final int c when c >= 26 && c <= 31 => thunderstorm,
    _ => null,
  };
}
