import 'package:tool_lab/l10n/app_localizations.dart';

import 'treadmill_health_connect_publisher.dart';

/// One wording for a publish outcome, shared by the settings sheet and the
/// history screen so a push is never reported as an import.
String treadmillPublishMessage(
  AppLocalizations l10n,
  TreadmillPublishResult? result,
) {
  if (result == null) return l10n.treadmillPublishNothing;
  return switch (result.outcome) {
    TreadmillPublishOutcome.unsupported => l10n.treadmillPublishUnsupported,
    TreadmillPublishOutcome.disabled => l10n.treadmillPublishDisabled,
    TreadmillPublishOutcome.noPermission => l10n.treadmillPublishNoPermission,
    TreadmillPublishOutcome.throttled => l10n.treadmillPublishThrottled,
    TreadmillPublishOutcome.ran when result.failed > 0 =>
      l10n.treadmillPublishFailed(result.failed),
    TreadmillPublishOutcome.ran when result.published > 0 =>
      l10n.treadmillPublishDone(result.published),
    TreadmillPublishOutcome.ran => l10n.treadmillPublishNothing,
  };
}
