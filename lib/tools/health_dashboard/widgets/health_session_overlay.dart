import 'package:flutter/material.dart';

import '../health_record_values.dart';

/// A curve drawn over a session's span - heart rate, breathing, speed, power.
///
/// Each one keeps its own lane and its own scale: the units share no range, so
/// a common axis would flatten every curve but the widest.
class HealthSessionOverlay {
  final String key;
  final String label;
  final String unit;
  final Color color;
  final List<HealthTimedValue> samples;

  const HealthSessionOverlay({
    required this.key,
    required this.label,
    required this.unit,
    required this.color,
    required this.samples,
  });

  /// Two samples are the minimum a line can be drawn from, and the minimum a
  /// range label means anything at.
  bool get isDrawable => samples.length >= 2;
}
