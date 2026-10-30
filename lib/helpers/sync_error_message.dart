import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sync_service.dart';

String syncErrorMessage(Object error, AppLocalizations l10n) {
  if (error is SyncPasswordMismatchException) {
    return l10n.totpSyncPasswordMismatch;
  }
  if (error is SyncUnsupportedPayloadException) {
    return l10n.totpSyncUnsupportedFormat;
  }
  if (error is SyncFailures) {
    return error.failures.entries
        .map((entry) => '${entry.key}: ${syncErrorMessage(entry.value, l10n)}')
        .join('; ');
  }
  return error.toString();
}
