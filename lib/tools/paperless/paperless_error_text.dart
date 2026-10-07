import 'package:tool_lab/l10n/app_localizations.dart';

import 'paperless_api.dart';

String describePaperlessError(AppLocalizations l10n, Object error) {
  if (error is! PaperlessException) return error.toString();
  return switch (error.kind) {
    PaperlessErrorKind.network => l10n.paperlessErrorNetwork(error.detail),
    PaperlessErrorKind.unauthorized => l10n.paperlessErrorUnauthorized,
    PaperlessErrorKind.invalidCredentials =>
      l10n.paperlessErrorInvalidCredentials,
    PaperlessErrorKind.notFound => l10n.paperlessErrorNotFound,
    PaperlessErrorKind.rejected => l10n.paperlessErrorRejected(error.detail),
    PaperlessErrorKind.server => l10n.paperlessErrorServer(error.detail),
    PaperlessErrorKind.invalidResponse => l10n.paperlessErrorInvalidResponse,
  };
}
