import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';

import 'models/depot_holding.dart';

class DepotColors {
  DepotColors._();

  static Color assetType(DepotAssetType type) => switch (type) {
    DepotAssetType.security => AppTheme.accentGreen,
    DepotAssetType.crypto => AppTheme.accentAmber,
    DepotAssetType.commodity => AppTheme.accentAmberLight,
    DepotAssetType.cash => AppTheme.accentBlue,
    DepotAssetType.custom => AppTheme.accentPurple,
    DepotAssetType.insurance => AppTheme.accentTeal,
    DepotAssetType.p2p => AppTheme.accentRed,
    DepotAssetType.realEstate => AppTheme.statusOrange,
  };
}
