import 'package:tool_lab/l10n/app_localizations.dart';

import 'depot_overlap.dart';
import 'depot_region.dart';
import 'dividends/depot_dividend_calendar.dart';
import 'models/depot_dividend.dart';
import 'models/depot_filters.dart';
import 'models/depot_holding.dart';
import 'models/depot_period.dart';
import 'models/depot_transaction.dart';
import 'parqet/parqet_auth.dart';
import 'parqet/parqet_exception.dart';

class DepotPortfolioLabels {
  DepotPortfolioLabels._();

  /// Plural, for filter chips and the allocation legend.
  static String kinds(AppLocalizations l10n, DepotHoldingKind kind) =>
      switch (kind) {
        DepotHoldingKind.stock => l10n.depotKindStocks,
        DepotHoldingKind.stockDividend => l10n.depotKindStockDividend,
        DepotHoldingKind.stockGrowth => l10n.depotKindStockGrowth,
        DepotHoldingKind.etf => l10n.depotKindEtfs,
        DepotHoldingKind.etfDistributing => l10n.depotKindEtfDistributing,
        DepotHoldingKind.etfAccumulating => l10n.depotKindEtfAccumulating,
        DepotHoldingKind.etc => l10n.depotKindEtcs,
        DepotHoldingKind.fund => l10n.depotKindFunds,
        DepotHoldingKind.fundDistributing => l10n.depotKindFundDistributing,
        DepotHoldingKind.fundAccumulating => l10n.depotKindFundAccumulating,
        DepotHoldingKind.crypto => l10n.depotAssetCrypto,
        DepotHoldingKind.commodity => l10n.depotAssetCommodity,
        DepotHoldingKind.cash => l10n.depotAssetCash,
        DepotHoldingKind.insurance => l10n.depotAssetInsurance,
        DepotHoldingKind.p2p => l10n.depotAssetP2p,
        DepotHoldingKind.realEstate => l10n.depotAssetRealEstate,
        DepotHoldingKind.other => l10n.depotAssetCustom,
      };

  static String overlapLevel(AppLocalizations l10n, DepotOverlapLevel level) =>
      switch (level) {
        DepotOverlapLevel.low => l10n.depotOverlapLevelLow,
        DepotOverlapLevel.moderate => l10n.depotOverlapLevelModerate,
        DepotOverlapLevel.high => l10n.depotOverlapLevelHigh,
      };

  /// Singular, for the badge on one holding.
  static String kind(AppLocalizations l10n, DepotHoldingKind kind) =>
      switch (kind) {
        DepotHoldingKind.stock => l10n.depotKindStock,
        DepotHoldingKind.etf => l10n.depotKindEtf,
        DepotHoldingKind.etc => l10n.depotKindEtc,
        DepotHoldingKind.fund => l10n.depotKindFund,
        _ => kinds(l10n, kind),
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
        DepotPeriod.days7 => l10n.depotRange7d,
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
        DepotHoldingSort.custom => l10n.depotSortCustom,
      };

  static String dividendStatus(
    AppLocalizations l10n,
    DepotDividendStatus status,
  ) => switch (status) {
    DepotDividendStatus.booked => l10n.depotDividendStatusBooked,
    DepotDividendStatus.missing => l10n.depotDividendStatusMissing,
    DepotDividendStatus.upcoming => l10n.depotDividendStatusUpcoming,
    DepotDividendStatus.projected => l10n.depotDividendStatusProjected,
  };

  static String frequency(
    AppLocalizations l10n,
    DepotDividendFrequency frequency,
  ) => switch (frequency) {
    DepotDividendFrequency.monthly => l10n.depotDividendFreqMonthly,
    DepotDividendFrequency.quarterly => l10n.depotDividendFreqQuarterly,
    DepotDividendFrequency.semiannual => l10n.depotDividendFreqSemiannual,
    DepotDividendFrequency.annual => l10n.depotDividendFreqAnnual,
    DepotDividendFrequency.irregular => l10n.depotDividendFreqIrregular,
  };

  static String region(AppLocalizations l10n, DepotRegion region) =>
      switch (region) {
        DepotRegion.northAmerica => l10n.depotRegionNorthAmerica,
        DepotRegion.southAmerica => l10n.depotRegionSouthAmerica,
        DepotRegion.europe => l10n.depotRegionEurope,
        DepotRegion.asia => l10n.depotRegionAsia,
        DepotRegion.oceania => l10n.depotRegionOceania,
        DepotRegion.africa => l10n.depotRegionAfrica,
        DepotRegion.other => l10n.depotRegionOther,
      };

  /// Yahoo's sector names (onvista's are mapped onto them), localized.
  /// Unknown names pass through.
  static String sector(AppLocalizations l10n, String name) => switch (name) {
    'Technology' => l10n.depotSectorTechnology,
    'Financial Services' => l10n.depotSectorFinancialServices,
    'Consumer Cyclical' => l10n.depotSectorConsumerCyclical,
    'Consumer Defensive' => l10n.depotSectorConsumerDefensive,
    'Healthcare' => l10n.depotSectorHealthcare,
    'Industrials' => l10n.depotSectorIndustrials,
    'Energy' => l10n.depotSectorEnergy,
    'Basic Materials' => l10n.depotSectorBasicMaterials,
    'Communication Services' => l10n.depotSectorCommunicationServices,
    'Utilities' => l10n.depotSectorUtilities,
    'Real Estate' => l10n.depotSectorRealEstate,
    'Consumer Goods' => l10n.depotSectorConsumerGoods,
    _ => name,
  };

  static String error(AppLocalizations l10n, ParqetException error) =>
      switch (error.kind) {
        ParqetErrorKind.notConnected => l10n.depotErrorNotConnected,
        ParqetErrorKind.unauthorized => l10n.depotErrorUnauthorized,
        ParqetErrorKind.denied => l10n.depotErrorDenied,
        ParqetErrorKind.scopeNotAllowed => l10n.depotErrorScopeNotAllowed,
        ParqetErrorKind.portBusy => l10n.depotErrorPortBusy(
          ParqetAuth.redirectPort,
        ),
        ParqetErrorKind.timeout => l10n.depotErrorTimeout,
        ParqetErrorKind.network => l10n.depotErrorNetwork,
        ParqetErrorKind.rateLimited => l10n.depotErrorRateLimited,
        ParqetErrorKind.server => l10n.depotErrorServer,
        ParqetErrorKind.invalidResponse => l10n.depotErrorInvalidResponse,
        ParqetErrorKind.localStorage => l10n.depotErrorLocalStorage,
      };
}
