import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class HealthSourceBadge extends StatelessWidget {
  final String? packageName;

  const HealthSourceBadge({super.key, required this.packageName});

  @override
  Widget build(BuildContext context) {
    final source = healthSourceFromPackage(packageName);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(source.icon, size: 16, color: Theme.of(context).hintColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            source.label(AppLocalizations.of(context)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

enum HealthSourceApp {
  treadmill,
  amazfit,
  huaweiHealth,
  googleFit,
  healthConnect,
}

HealthSourceApp healthSourceFromPackage(String? packageName) =>
    switch (packageName) {
      'ToolLab Treadmill' => HealthSourceApp.treadmill,
      'com.huami.watch.hmwatchmanager' => HealthSourceApp.amazfit,
      'com.huawei.health' => HealthSourceApp.huaweiHealth,
      'com.huawei.health.beta' => HealthSourceApp.huaweiHealth,
      'com.google.android.apps.fitness' => HealthSourceApp.googleFit,
      _ => HealthSourceApp.healthConnect,
    };

extension HealthSourceAppDetails on HealthSourceApp {
  IconData get icon => switch (this) {
    HealthSourceApp.treadmill => Icons.directions_run_rounded,
    HealthSourceApp.amazfit => Icons.watch_outlined,
    HealthSourceApp.huaweiHealth => Icons.watch_outlined,
    HealthSourceApp.googleFit => Icons.fitness_center_outlined,
    HealthSourceApp.healthConnect => Icons.health_and_safety_outlined,
  };

  String label(AppLocalizations l10n) => switch (this) {
    HealthSourceApp.treadmill => l10n.toolNameTreadmillControl,
    HealthSourceApp.amazfit => l10n.healthDashboardAmazfit,
    HealthSourceApp.huaweiHealth => l10n.healthDashboardHuaweiHealth,
    HealthSourceApp.googleFit => l10n.healthDashboardGoogleFit,
    HealthSourceApp.healthConnect => l10n.healthDashboardHealthConnect,
  };
}
