import 'package:tool_lab/theme/theme.dart';
import 'package:flutter/material.dart';

import 'renpho_assessment.dart';
import 'renpho_independent_analysis.dart';

/// One colour per series, so a metric keeps its identity across the hero, the
/// tiles, the charts and the segment table.
class RenphoColors {
  RenphoColors._();

  static const weight = AppTheme.accentPurple;
  static const bodyFat = AppTheme.accentAmber;
  static const muscle = AppTheme.accentTeal;
  static const water = AppTheme.accentBlue;
  static const bone = Color(0xFF9E9E9E);
  static const visceral = AppTheme.accentRed;
  static const energy = AppTheme.accentGreen;

  static Color rating(RenphoRating rating) => switch (rating) {
    RenphoRating.optimal => AppTheme.statusGreen,
    RenphoRating.low || RenphoRating.elevated => AppTheme.statusAmber,
    RenphoRating.high => AppTheme.statusRed,
  };

  static Color overall(RenphoOverallStatus status) => switch (status) {
    RenphoOverallStatus.excellent ||
    RenphoOverallStatus.good => AppTheme.statusGreen,
    RenphoOverallStatus.fair => AppTheme.statusAmber,
    RenphoOverallStatus.attention => AppTheme.statusRed,
  };
}
