import 'dart:math' as math;

const double silenceDb = -90;

/// Linear amplitude (0..1) to dBFS, never below [floor].
double ampToDb(double amp, {double floor = silenceDb}) {
  if (amp <= 0) return floor;
  return math.max(floor, 20 * math.log(amp) / math.ln10);
}

double dbToAmp(double db) => math.pow(10, db / 20).toDouble();
