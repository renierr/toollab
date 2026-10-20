import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// Health Connect sleep stage names folded into the stages the charts draw.
enum SleepStageKind {
  awake,
  rem,
  light,
  deep,

  /// Asleep without a finer stage, e.g. a writer that only reports "sleeping".
  asleep;

  static SleepStageKind? fromName(String? name) => switch (name) {
    'awake' || 'outOfBed' || 'inBed' => awake,
    'rem' => rem,
    'light' => light,
    'deep' => deep,
    'sleeping' => asleep,
    _ => null,
  };

  Color get color => switch (this) {
    awake => Colors.amber,
    rem => Colors.purple,
    light => Colors.lightBlue,
    deep => Colors.indigo,
    asleep => Colors.blueGrey,
  };

  String label(AppLocalizations l10n) => switch (this) {
    awake => l10n.healthDashboardSleepAwake,
    rem => l10n.healthDashboardSleepRem,
    light => l10n.healthDashboardSleepLight,
    deep => l10n.healthDashboardSleepDeep,
    asleep => l10n.healthDashboardSleepAsleep,
  };
}
