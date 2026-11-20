import 'dart:math' as math;

import 'weather_settings.dart';

/// Converts the SI values of the models into the user's units.
class WeatherUnits {
  const WeatherUnits(this.settings);

  final WeatherSettings settings;

  double temperature(double celsius) =>
      settings.temperatureUnit == TemperatureUnit.fahrenheit
      ? celsius * 9 / 5 + 32
      : celsius;

  String temperatureText(double? celsius, {bool withUnit = false}) {
    if (celsius == null) return '–';
    final value = '${temperature(celsius).round()}°';
    if (!withUnit) return value;
    return settings.temperatureUnit == TemperatureUnit.fahrenheit
        ? '${value}F'
        : '${value}C';
  }

  double wind(double ms) => switch (settings.windUnit) {
    WindUnit.kmh => ms * 3.6,
    WindUnit.ms => ms,
    WindUnit.knots => ms * 1.943844,
    WindUnit.mph => ms * 2.236936,
    WindUnit.beaufort => beaufort(ms).toDouble(),
  };

  String get windSymbol => switch (settings.windUnit) {
    WindUnit.kmh => 'km/h',
    WindUnit.ms => 'm/s',
    WindUnit.knots => 'kn',
    WindUnit.mph => 'mph',
    WindUnit.beaufort => 'Bft',
  };

  String windText(double? ms) {
    if (ms == null) return '–';
    final v = wind(ms);
    final digits = settings.windUnit == WindUnit.ms && v < 10 ? 1 : 0;
    return '${v.toStringAsFixed(digits)} $windSymbol';
  }

  String pressureText(double? hPa) {
    if (hPa == null) return '–';
    return switch (settings.pressureUnit) {
      PressureUnit.hPa => '${hPa.round()} hPa',
      PressureUnit.mmHg => '${(hPa * 0.750062).round()} mmHg',
      PressureUnit.inHg => '${(hPa * 0.0295300).toStringAsFixed(2)} inHg',
    };
  }

  String precipitationText(double? mm) {
    if (mm == null) return '–';
    if (settings.precipitationUnit == PrecipitationUnit.inch) {
      return '${(mm / 25.4).toStringAsFixed(2)} in';
    }
    return mm < 10 ? '${mm.toStringAsFixed(1)} mm' : '${mm.round()} mm';
  }

  static String percentText(double? percent) =>
      percent == null ? '–' : '${percent.round()} %';

  static String visibilityText(double? metres) {
    if (metres == null) return '–';
    return metres < 1000
        ? '${metres.round()} m'
        : '${(metres / 1000).round()} km';
  }

  static int beaufort(double ms) {
    const limits = [
      0.3,
      1.6,
      3.4,
      5.5,
      8.0,
      10.8,
      13.9,
      17.2,
      20.8,
      24.5,
      28.5,
      32.7,
    ];
    for (var i = 0; i < limits.length; i++) {
      if (ms < limits[i]) return i;
    }
    return 12;
  }

  /// 16-point compass index, 0 = N; the caller maps it to a localized label.
  static int compassIndex(double degrees) =>
      ((degrees % 360) / 22.5).round() % 16;

  static double normalizeDegrees(double degrees) => (degrees % 360 + 360) % 360;

  static double toRadians(double degrees) => degrees * math.pi / 180;
}
