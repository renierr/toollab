import 'dart:math';

/// Represents a single reading of the Electromagnetic Field.
class EmfReading {
  final double x;
  final double y;
  final double z;
  final double magnitude;

  // Baseline values (calibration offset)
  final double baselineX;
  final double baselineY;
  final double baselineZ;

  final DateTime timestamp;

  EmfReading({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
    this.baselineX = 0.0,
    this.baselineY = 0.0,
    this.baselineZ = 0.0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates a reading from raw x, y, z magnetometer components in microteslas (uT).
  ///
  /// Optionally accepts baseline calibration offsets.
  factory EmfReading.fromRaw(
    double x,
    double y,
    double z, {
    double baselineX = 0.0,
    double baselineY = 0.0,
    double baselineZ = 0.0,
  }) {
    final mag = sqrt(x * x + y * y + z * z);
    return EmfReading(
      x: x,
      y: y,
      z: z,
      magnitude: mag,
      baselineX: baselineX,
      baselineY: baselineY,
      baselineZ: baselineZ,
    );
  }

  /// Calculates the delta components relative to the calibrated baseline.
  double get deltaX => x - baselineX;
  double get deltaY => y - baselineY;
  double get deltaZ => z - baselineZ;

  /// The true vector delta magnitude. This measures the net change in the
  /// magnetic vector from the calibrated state. This is highly effective
  /// for wire/stud scanning because it eliminates background ambient fields.
  double get deltaMagnitude {
    final dx = deltaX;
    final dy = deltaY;
    final dz = deltaZ;
    return sqrt(dx * dx + dy * dy + dz * dz);
  }

  /// Returns a new reading with the given baseline applied.
  EmfReading withBaseline(double bX, double bY, double bZ) {
    return EmfReading(
      x: x,
      y: y,
      z: z,
      magnitude: magnitude,
      baselineX: bX,
      baselineY: bY,
      baselineZ: bZ,
      timestamp: timestamp,
    );
  }

  @override
  String toString() {
    return 'EmfReading(x: ${x.toStringAsFixed(1)}, y: ${y.toStringAsFixed(1)}, z: ${z.toStringAsFixed(1)}, mag: ${magnitude.toStringAsFixed(1)}, deltaMag: ${deltaMagnitude.toStringAsFixed(1)})';
  }
}
