import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';

import 'dividends/depot_dividend_calendar.dart';
import 'models/depot_holding.dart';

class DepotColors {
  DepotColors._();

  static Color kind(DepotHoldingKind kind) => switch (kind) {
    DepotHoldingKind.stock => AppTheme.accentGreen,
    DepotHoldingKind.etf => AppTheme.accentBlue,
    DepotHoldingKind.fund => AppTheme.accentTeal,
    DepotHoldingKind.crypto => AppTheme.accentAmber,
    DepotHoldingKind.commodity => AppTheme.accentAmberLight,
    DepotHoldingKind.cash => AppTheme.statusOrange,
    DepotHoldingKind.insurance => AppTheme.accentPurple,
    DepotHoldingKind.p2p => AppTheme.accentRed,
    DepotHoldingKind.realEstate => AppTheme.statusRed,
    DepotHoldingKind.other => AppTheme.statusBlue,
  };

  static const Color dividendBooked = AppTheme.accentTeal;
  static const Color dividendMissing = AppTheme.accentAmber;
  static const Color dividendExpected = AppTheme.accentBlue;

  static Color dividend(DepotDividendStatus status) => switch (status) {
    DepotDividendStatus.booked => dividendBooked,
    DepotDividendStatus.missing => dividendMissing,
    DepotDividendStatus.upcoming ||
    DepotDividendStatus.projected => dividendExpected,
  };

  /// A stable color per holding, spread around the hue circle so neighbours
  /// in the list rarely look alike.
  static Color holding(String seed) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    // Golden-angle steps keep consecutive hashes far apart in hue.
    final hue = (hash * 137.508) % 360;
    return HSLColor.fromAHSL(1, hue, 0.55, 0.58).toColor();
  }
}
