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
    PaperlessErrorKind.rejected => _describeRejected(l10n, error),
    PaperlessErrorKind.server => l10n.paperlessErrorServer(error.detail),
    PaperlessErrorKind.invalidResponse => l10n.paperlessErrorInvalidResponse,
  };
}

final _duplicatePattern = RegExp(
  r'duplicate|already exists|bereits vorhanden|duplikat',
  caseSensitive: false,
);

// "scan.pdf: Not consuming scan.pdf: It is a duplicate of ..." repeats the
// file name twice; the part after the second colon is the actual reason.
final _consumePrefix = RegExp(
  r'^[^:]{1,120}:\s*Not consuming\s+[^:]{1,120}:\s*',
);

String _describeRejected(AppLocalizations l10n, PaperlessException error) {
  final detail = _cleanDetail(error.detail);
  final duplicateId = error.duplicateDocumentId;
  final isDuplicate = duplicateId != null || _duplicatePattern.hasMatch(detail);
  if (detail.isEmpty) {
    if (duplicateId != null) {
      return l10n.paperlessErrorDuplicateNoDetail(duplicateId);
    }
    return l10n.paperlessErrorRejectedNoDetail;
  }
  if (isDuplicate) {
    if (duplicateId != null) {
      return l10n.paperlessErrorDuplicateWithId(duplicateId, detail);
    }
    return l10n.paperlessErrorDuplicate(detail);
  }
  return l10n.paperlessErrorRejected(detail);
}

String _cleanDetail(String detail) {
  var text = detail.trim();
  text = text.replaceFirst(_consumePrefix, '').trim();
  return text;
}
