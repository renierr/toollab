import 'package:tool_lab/l10n/app_localizations.dart';

import 'models/depot_activity.dart';

/// ARB keys cannot be looked up dynamically, so the enum-to-string mapping
/// lives here instead of being repeated in every widget.
class DepotLabels {
  DepotLabels._();

  static String issue(AppLocalizations l10n, DepotParseIssue issue) =>
      switch (issue) {
        DepotParseIssue.noText => l10n.depotImportIssueNoText,
        DepotParseIssue.unknownType => l10n.depotImportIssueUnknownType,
        DepotParseIssue.missingIsin => l10n.depotImportIssueMissingIsin,
        DepotParseIssue.invalidIsin => l10n.depotImportIssueInvalidIsin,
        DepotParseIssue.missingDate => l10n.depotImportIssueMissingDate,
        DepotParseIssue.missingShares => l10n.depotImportIssueMissingShares,
        DepotParseIssue.missingPrice => l10n.depotImportIssueMissingPrice,
        DepotParseIssue.missingAmount => l10n.depotImportIssueMissingAmount,
        DepotParseIssue.missingFxRate => l10n.depotImportIssueMissingFxRate,
        DepotParseIssue.amountMismatch => l10n.depotImportIssueAmountMismatch,
        DepotParseIssue.totalMismatch => l10n.depotImportIssueTotalMismatch,
        DepotParseIssue.duplicate => l10n.depotImportIssueDuplicate,
      };

  static String type(AppLocalizations l10n, DepotActivityType type) =>
      switch (type) {
        DepotActivityType.buy => l10n.depotImportTypeBuy,
        DepotActivityType.sell => l10n.depotImportTypeSell,
        DepotActivityType.dividend => l10n.depotImportTypeDividend,
      };

  static String bank(AppLocalizations l10n, DepotBank bank) => switch (bank) {
    DepotBank.dkb => 'DKB',
    DepotBank.ing => 'ING',
    DepotBank.unknown => l10n.depotImportBankUnknown,
  };

  static String date(DateTime? date) {
    if (date == null) return '';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  static String number(double value, int decimals) {
    var text = value.toStringAsFixed(decimals);
    if (text.contains('.')) {
      text = text
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }
    return text.replaceAll('.', ',');
  }
}
