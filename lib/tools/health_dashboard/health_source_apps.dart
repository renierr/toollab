import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import 'health_debug_origin.dart';

/// Friendly names and icons for the apps that write into Health Connect.
///
/// Single source of truth: the settings screens, the source badge and the app
/// priority list all resolve a package through here, so a writer is named the
/// same everywhere.
///
/// An unrecognised writer falls back to its package name. It must never fall
/// back to a generic "Health Connect" label - a scale nobody has a mapping for
/// then reads as if Health Connect itself measured it.
enum HealthSourceApp {
  toolLab,
  nutriScan,
  amazfit,
  huaweiHealth,
  googleFit,
  samsungHealth,
  fitbit,
  garmin,
  withings,
  renpho,
  miFitness,
  healthConnect,
  generated,
  unknown,
}

/// Exact package names first; [_prefixes] catches vendors who ship several
/// package variants (regional builds, betas, renamed successors).
const _packages = <String, HealthSourceApp>{
  'ToolLab Treadmill': HealthSourceApp.toolLab,
  healthDebugPackage: HealthSourceApp.generated,
  'de.renier.tool_lab': HealthSourceApp.toolLab,
  'de.renier.calorie_tracker': HealthSourceApp.nutriScan,
  'com.huami.watch.hmwatchmanager': HealthSourceApp.amazfit,
  'com.google.android.apps.fitness': HealthSourceApp.googleFit,
  'com.google.android.apps.healthdata': HealthSourceApp.healthConnect,
};

const _prefixes = <String, HealthSourceApp>{
  'com.huawei.health': HealthSourceApp.huaweiHealth,
  'com.huami.': HealthSourceApp.amazfit,
  'com.zepp.': HealthSourceApp.amazfit,
  'com.xiaomi.wearable': HealthSourceApp.miFitness,
  'com.mi.health': HealthSourceApp.miFitness,
  'com.sec.android.app.shealth': HealthSourceApp.samsungHealth,
  'com.samsung.android.health': HealthSourceApp.samsungHealth,
  'com.fitbit.': HealthSourceApp.fitbit,
  'com.garmin.': HealthSourceApp.garmin,
  'com.withings.': HealthSourceApp.withings,
  'com.renpho.': HealthSourceApp.renpho,
};

HealthSourceApp healthSourceFromPackage(String? packageName) {
  if (packageName == null || packageName.isEmpty) {
    return HealthSourceApp.unknown;
  }
  final exact = _packages[packageName];
  if (exact != null) return exact;
  for (final entry in _prefixes.entries) {
    if (packageName.startsWith(entry.key)) return entry.value;
  }
  return HealthSourceApp.unknown;
}

/// Display name for a writer package, falling back to the package itself.
String healthAppLabel(String? packageName, AppLocalizations l10n) {
  final app = healthSourceFromPackage(packageName);
  if (app == HealthSourceApp.unknown) {
    return packageName ?? l10n.healthDashboardSourceUnknown;
  }
  return app.label(l10n);
}

IconData healthAppIcon(String? packageName) =>
    healthSourceFromPackage(packageName).icon;

extension HealthSourceAppDetails on HealthSourceApp {
  IconData get icon => switch (this) {
    HealthSourceApp.toolLab => Icons.handyman_outlined,
    HealthSourceApp.nutriScan => Icons.restaurant_rounded,
    HealthSourceApp.amazfit ||
    HealthSourceApp.huaweiHealth ||
    HealthSourceApp.samsungHealth ||
    HealthSourceApp.fitbit ||
    HealthSourceApp.garmin ||
    HealthSourceApp.miFitness => Icons.watch_outlined,
    HealthSourceApp.googleFit => Icons.fitness_center_outlined,
    HealthSourceApp.withings ||
    HealthSourceApp.renpho => Icons.monitor_weight_outlined,
    HealthSourceApp.healthConnect => Icons.health_and_safety_outlined,
    HealthSourceApp.generated => Icons.bug_report_outlined,
    HealthSourceApp.unknown => Icons.apps_rounded,
  };

  String label(AppLocalizations l10n) => switch (this) {
    HealthSourceApp.toolLab => 'ToolLab',
    HealthSourceApp.nutriScan => 'NutriScan',
    HealthSourceApp.amazfit => l10n.healthDashboardAmazfit,
    HealthSourceApp.huaweiHealth => l10n.healthDashboardHuaweiHealth,
    HealthSourceApp.googleFit => l10n.healthDashboardGoogleFit,
    HealthSourceApp.samsungHealth => l10n.healthDashboardSamsungHealth,
    HealthSourceApp.fitbit => l10n.healthDashboardFitbit,
    HealthSourceApp.garmin => l10n.healthDashboardGarmin,
    HealthSourceApp.withings => l10n.healthDashboardWithings,
    HealthSourceApp.renpho => l10n.healthDashboardRenpho,
    HealthSourceApp.miFitness => l10n.healthDashboardMiFitness,
    HealthSourceApp.healthConnect => l10n.healthDashboardSourceHealthConnect,
    HealthSourceApp.generated => l10n.healthDebugSourceGenerated,
    HealthSourceApp.unknown => l10n.healthDashboardSourceUnknown,
  };
}
