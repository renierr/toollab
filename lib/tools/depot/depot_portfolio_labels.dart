import 'package:tool_lab/l10n/app_localizations.dart';

import 'models/depot_filters.dart';
import 'models/depot_holding.dart';
import 'models/depot_period.dart';
import 'models/depot_transaction.dart';
import 'parqet/parqet_auth.dart';
import 'parqet/parqet_exception.dart';

class DepotPortfolioLabels {
  DepotPortfolioLabels._();

  static String assetType(AppLocalizations l10n, DepotAssetType type) =>
      switch (type) {
        DepotAssetType.security => l10n.depotAssetSecurity,
        DepotAssetType.crypto => l10n.depotAssetCrypto,
        DepotAssetType.commodity => l10n.depotAssetCommodity,
        DepotAssetType.cash => l10n.depotAssetCash,
        DepotAssetType.custom => l10n.depotAssetCustom,
        DepotAssetType.insurance => l10n.depotAssetInsurance,
        DepotAssetType.p2p => l10n.depotAssetP2p,
        DepotAssetType.realEstate => l10n.depotAssetRealEstate,
      };

  static String transactionType(
    AppLocalizations l10n,
    DepotTransactionType type,
  ) => switch (type) {
    DepotTransactionType.buy => l10n.depotTxBuy,
    DepotTransactionType.sell => l10n.depotTxSell,
    DepotTransactionType.dividend => l10n.depotTxDividend,
    DepotTransactionType.interest => l10n.depotTxInterest,
    DepotTransactionType.transferIn => l10n.depotTxTransferIn,
    DepotTransactionType.transferOut => l10n.depotTxTransferOut,
    DepotTransactionType.feesTaxes => l10n.depotTxFeesTaxes,
    DepotTransactionType.deposit => l10n.depotTxDeposit,
    DepotTransactionType.withdrawal => l10n.depotTxWithdrawal,
  };

  static String period(AppLocalizations l10n, DepotPeriod period) =>
      switch (period) {
        DepotPeriod.today => l10n.depotRangeToday,
        DepotPeriod.month1 => l10n.depotRange1m,
        DepotPeriod.month3 => l10n.depotRange3m,
        DepotPeriod.ytd => l10n.depotRangeYtd,
        DepotPeriod.year1 => l10n.depotRange1y,
        DepotPeriod.year3 => l10n.depotRange3y,
        DepotPeriod.max => l10n.depotRangeMax,
      };

  static String sort(AppLocalizations l10n, DepotHoldingSort sort) =>
      switch (sort) {
        DepotHoldingSort.value => l10n.depotSortValue,
        DepotHoldingSort.gain => l10n.depotSortGain,
        DepotHoldingSort.returnPercent => l10n.depotSortGainPercent,
        DepotHoldingSort.name => l10n.depotSortName,
      };

  static String error(AppLocalizations l10n, ParqetException error) =>
      switch (error.kind) {
        ParqetErrorKind.notConnected => l10n.depotErrorNotConnected,
        ParqetErrorKind.unauthorized => l10n.depotErrorUnauthorized,
        ParqetErrorKind.denied => l10n.depotErrorDenied,
        ParqetErrorKind.portBusy => l10n.depotErrorPortBusy(
          ParqetAuth.redirectPort,
        ),
        ParqetErrorKind.timeout => l10n.depotErrorTimeout,
        ParqetErrorKind.network => l10n.depotErrorNetwork,
        ParqetErrorKind.rateLimited => l10n.depotErrorRateLimited,
        ParqetErrorKind.server => l10n.depotErrorServer,
        ParqetErrorKind.invalidResponse => l10n.depotErrorInvalidResponse,
      };
}
