import 'dart:math' as math;

/// Units that name the metric instead of trailing the number ("1234", not
/// "1234 steps").
const _bareUnits = {'steps', 'calories', 'count', 'BMI'};

/// Fraction digits per display unit — the single source of truth, so a metric
/// never renders at two precisions across pages.
int healthFractionDigits(String unit) => switch (unit) {
  'kg' || 'km' || '%' || 'L' || 'mmol/L' || 'BMI' => 2,
  'ms' ||
  'cm' ||
  'm' ||
  'km/h' ||
  'rpm' ||
  '/min' ||
  'mL/kg/min' ||
  'C' ||
  '°C' => 1,
  _ => 0,
};

/// Chart ticks stay coarse; the readouts next to them carry full precision.
int healthAxisFractionDigits(String unit) =>
    math.min(healthFractionDigits(unit), 1);

String healthNumber(num value, String unit) =>
    value.toStringAsFixed(healthFractionDigits(unit));

String healthAxisNumber(num value, String unit) =>
    value.toStringAsFixed(healthAxisFractionDigits(unit));

/// Number plus unit suffix, dropping units that are labels rather than suffixes.
String healthValue(num value, String unit) {
  final text = healthNumber(value, unit);
  return unit.isEmpty || _bareUnits.contains(unit) ? text : '$text $unit';
}

/// A metric readout: like [healthValue], except "min" is a count of minutes and
/// reads as hours and minutes wherever it is shown.
String healthMetricValue(num value, String unit) {
  if (unit != 'min') return healthValue(value, unit);
  final minutes = value.round();
  final hours = minutes ~/ 60;
  return hours > 0 ? '${hours}h ${minutes.remainder(60)}m' : '${minutes}m';
}
