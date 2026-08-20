import 'package:tool_lab/l10n/app_localizations.dart';

import 'renpho_health_connect_publisher.dart';

/// One wording for a publish outcome, shared by the settings sheet and the
/// dashboard so a push is never reported as an import.
String renphoPublishMessage(
  AppLocalizations l10n,
  RenphoPublishResult? result,
) {
  if (result == null) return l10n.renphoPublishNothing;
  return switch (result.outcome) {
    RenphoPublishOutcome.unsupported => l10n.renphoPublishUnsupported,
    RenphoPublishOutcome.disabled => l10n.renphoPublishDisabled,
    RenphoPublishOutcome.noPermission => l10n.renphoPublishNoPermission,
    RenphoPublishOutcome.throttled => l10n.renphoPublishThrottled,
    RenphoPublishOutcome.ran when result.failed > 0 => l10n.renphoPublishFailed(
      result.failed,
    ),
    RenphoPublishOutcome.ran when result.published > 0 =>
      l10n.renphoPublishDone(result.published),
    RenphoPublishOutcome.ran => l10n.renphoPublishNothing,
  };
}
