import 'package:material_ui/material_ui.dart';

import 'models/weather_condition.dart';

class WeatherColors {
  WeatherColors._();

  static const Color sun = Color(0xFFFFC23D);
  static const Color sunCore = Color(0xFFFFE08A);
  static const Color moon = Color(0xFFE6E9F5);
  static const Color cloudLight = Color(0xFFF4F7FB);
  static const Color cloudDark = Color(0xFF9AA6B8);
  static const Color rain = Color(0xFF4FA8FF);
  static const Color snow = Color(0xFFFFFFFF);
  static const Color lightning = Color(0xFFFFD84D);
  static const Color fog = Color(0xFFCBD3DE);

  static const Color precipitationBar = Color(0xFF4FA8FF);
  static const Color temperatureLine = Color(0xFFFFB347);
  static const Color windLine = Color(0xFF7ED7C1);
  static const Color pressureLine = Color(0xFFB39DDB);

  static const Color warningLevel1 = Color(0xFFFFEB3B);
  static const Color warningLevel2 = Color(0xFFFF9800);
  static const Color warningLevel3 = Color(0xFFE53935);
  static const Color warningLevel4 = Color(0xFF8E24AA);

  static Color warning(int level) => switch (level) {
    <= 1 => warningLevel1,
    2 => warningLevel2,
    3 => warningLevel3,
    _ => warningLevel4,
  };

  static Color onWarning(int level) => level <= 2 ? Colors.black : Colors.white;

  /// Hero background by sky state and daylight.
  static List<Color> sky(WeatherCondition condition, {required bool isDay}) {
    if (!isDay) {
      return switch (condition) {
        WeatherCondition.clear || WeatherCondition.mostlyClear => const [
          Color(0xFF0B1638),
          Color(0xFF253A75),
        ],
        WeatherCondition.thunderstorm => const [
          Color(0xFF14101F),
          Color(0xFF3B2F55),
        ],
        _ => const [Color(0xFF151B2B), Color(0xFF3A4458)],
      };
    }
    return switch (condition) {
      WeatherCondition.clear => const [Color(0xFF2E8BF0), Color(0xFF7CC4FF)],
      WeatherCondition.mostlyClear => const [
        Color(0xFF3B8EE0),
        Color(0xFF9CCBF2),
      ],
      WeatherCondition.partlyCloudy => const [
        Color(0xFF4F86C6),
        Color(0xFFA8C3DE),
      ],
      WeatherCondition.cloudy ||
      WeatherCondition.overcast => const [Color(0xFF5E6E85), Color(0xFF9AA8BA)],
      WeatherCondition.fog => const [Color(0xFF7D8896), Color(0xFFBFC7D1)],
      WeatherCondition.thunderstorm => const [
        Color(0xFF2D3142),
        Color(0xFF5C5470),
      ],
      _ when condition.isSnowy => const [Color(0xFF6D8AAE), Color(0xFFC9D8EA)],
      _ => const [Color(0xFF3E5470), Color(0xFF7890AB)],
    };
  }

  /// Blue (cold) through green to red (hot) for a temperature in °C.
  static Color temperature(double celsius) {
    const stops = <(double, Color)>[
      (-15, Color(0xFF7B61FF)),
      (-5, Color(0xFF3D8BFF)),
      (3, Color(0xFF3FC5F0)),
      (10, Color(0xFF4CD4A0)),
      (17, Color(0xFFB8E05A)),
      (23, Color(0xFFFFC94A)),
      (29, Color(0xFFFF8A3D)),
      (35, Color(0xFFE5484D)),
    ];
    if (celsius <= stops.first.$1) return stops.first.$2;
    for (var i = 1; i < stops.length; i++) {
      if (celsius <= stops[i].$1) {
        final (t0, c0) = stops[i - 1];
        final (t1, c1) = stops[i];
        return Color.lerp(c0, c1, (celsius - t0) / (t1 - t0))!;
      }
    }
    return stops.last.$2;
  }
}
