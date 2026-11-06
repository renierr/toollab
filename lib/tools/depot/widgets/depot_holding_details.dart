import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/data_row.dart';

import '../depot_allocation_state.dart';
import '../depot_details_link.dart';
import '../depot_dividend_state.dart';
import '../depot_format.dart';
import '../depot_holding_trend_state.dart';
import '../depot_portfolio_labels.dart';
import '../depot_portfolio_state.dart';
import '../depot_savings_plans.dart';
import '../depot_state.dart';
import '../dividends/depot_dividend_calendar.dart';
import '../models/depot_asset_profile.dart';
import '../models/depot_filters.dart';
import '../models/depot_holding.dart';
import '../models/depot_holding_trend.dart';
import '../models/depot_period.dart';
import '../models/depot_transaction.dart';
import 'depot_details_link_button.dart';
import 'depot_wishlist_holding_button.dart';

/// Every figure of one holding, shown when its row is expanded.
class DepotHoldingDetails extends StatelessWidget {
  final DepotHolding holding;
  final DepotHoldingPerformance? performance;
  final DepotPeriod period;
  final DepotFormat format;
  final double weight;

  const DepotHoldingDetails({
    super.key,
    required this.holding,
    required this.performance,
    required this.period,
    required this.format,
    required this.weight,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final h = holding;
    final periodLabel = DepotPortfolioLabels.period(l10n, period);
    final gain = performance?.gain;
    final returnPercent = performance?.returnPercent;
    final xirr = h.xirr;
    final quoteAt = h.quoteAt;
    final exchange = h.quoteExchange;
    final startPrice = performance?.startPrice;
    final earliest = h.earliestActivity;
    final isin = h.assetType == DepotAssetType.security ? h.isin : null;
    final linkKind = DepotDetailsLinkKind.of(h.kind);
    final hasSales = context.select<DepotPortfolioState?, bool>(
      (state) => state?.hasSalesFor(h) ?? false,
    );
    final profile = context.select<DepotAllocationState?, DepotAssetProfile?>(
      (state) => state?.profileOf(h),
    );
    final expenseRatio = profile?.expenseRatio;
    final sector = profile?.sector;
    final industry = profile?.industry;
    final country = profile?.country;
    final plan = context.select<DepotPortfolioState?, DepotSavingsPlan?>(
      (state) => state?.savingsPlans.of(h),
    );
    final portfolio = context
        .select<
          DepotPortfolioState?,
          (List<DepotHolding>, List<DepotTransaction>, String)?
        >(
          (state) => state == null
              ? null
              : (state.holdings, state.transactions, state.currency),
        );
    final currency = portfolio?.$3;
    final trend = context.select<DepotHoldingTrendState?, DepotHoldingTrend?>(
      (state) => state?.trendFor(h),
    );
    final rate = context.select<DepotHoldingTrendState?, double?>(
      (state) => trend == null || currency == null
          ? null
          : state?.rate(trend.currency, currency),
    );
    final dividend = context
        .select<DepotDividendState?, DepotDividendPosition?>(
          (state) => portfolio == null
              ? null
              : state
                    ?.calendarFor(portfolio.$1, portfolio.$2, portfolio.$3)
                    .positions
                    .where(
                      (p) =>
                          p.holding.id == h.id &&
                          p.holding.portfolioId == h.portfolioId,
                    )
                    .firstOrNull,
        );
    final dividendYield = dividend?.yieldPercent;
    final frequency = dividend?.frequency;
    final next = dividend?.next;
    final nextExDate = next?.exDate;
    final estimated = next?.status == DepotDividendStatus.projected ? '≈ ' : '';
    String day(DateTime date) =>
        FormatHelper.dateTime(date, style: DateStyle.dateOnly);

    // Yahoo quotes in the listing currency; converted when the rate is known.
    String listingRange(double? low, double? high) {
      if (trend == null || trend.currency.isEmpty) return '';
      if (low == null || high == null) return '';
      final listing = DepotFormat.of(context, trend.currency);
      final text = '${listing.money(low)} – ${listing.money(high)}';
      if (trend.currency == currency || rate == null) return text;
      return '≈ ${format.money(low * rate)} – ${format.money(high * rate)} '
          '($text)';
    }

    final dayRange = listingRange(trend?.dayLow, trend?.dayHigh);
    final yearRange = listingRange(trend?.yearLow, trend?.yearHigh);

    final rows = <(String, String)>[
      (l10n.depotDetailType, DepotPortfolioLabels.kind(l10n, h.kind)),
      if (h.isin != null) (l10n.depotDetailIsin, h.isin!),
      if (expenseRatio != null)
        (
          l10n.depotDetailExpenseRatio,
          l10n.depotDetailExpenseRatioValue(
            format.percent(expenseRatio * 100, signed: false),
            format.money(h.currentValue * expenseRatio),
          ),
        ),
      if (h.isin == null && h.symbol != null)
        (l10n.depotDetailSymbol, h.symbol!),
      if (sector != null && sector.isNotEmpty)
        (l10n.depotDetailSector, DepotPortfolioLabels.sector(l10n, sector)),
      if (industry != null && industry.isNotEmpty)
        (l10n.depotDetailIndustry, industry),
      if (country != null && country.isNotEmpty)
        (l10n.depotDetailCountry, country),
      if (plan != null)
        (
          l10n.depotHoldingSavingsPlan,
          l10n.depotHoldingSavingsPlanValue(
            DepotFormat.of(context, plan.currency).money(plan.rate),
            plan.day,
          ),
        ),
      if (h.shares != 0) (l10n.depotDetailShares, format.shares(h.shares)),
      if (h.purchasePrice != 0)
        (l10n.depotDetailPurchasePrice, format.money(h.purchasePrice)),
      if (h.currentPrice != 0)
        (l10n.depotDetailCurrentPrice, format.money(h.currentPrice)),
      if (startPrice != null && startPrice != 0)
        (
          period == DepotPeriod.today
              ? l10n.depotDetailPreviousClose
              : l10n.depotDetailStartPrice(periodLabel),
          format.money(startPrice),
        ),
      if (dayRange.isNotEmpty) (l10n.depotWishlistDayRange, dayRange),
      if (yearRange.isNotEmpty) (l10n.depotWishlistYearRange, yearRange),
      if (quoteAt != null)
        (l10n.depotDetailQuoteAt, FormatHelper.dateTime(quoteAt)),
      if (exchange != null && exchange.isNotEmpty)
        (l10n.depotDetailExchange, exchange),
      (l10n.depotDetailPurchaseValue, format.money(h.purchaseValue)),
      (l10n.depotDetailCurrentValue, format.money(h.currentValue)),
      if (weight > 0)
        (l10n.depotDetailWeight, format.percent(weight, signed: false)),
      if (gain != null)
        (
          l10n.depotDetailPeriodGain(periodLabel),
          format.money(gain, signed: true),
        ),
      if (returnPercent != null)
        (
          l10n.depotDetailPeriodReturn(periodLabel),
          format.percent(returnPercent),
        ),
      (
        l10n.depotDetailUnrealized,
        '${format.money(h.unrealizedGain, signed: true)} '
            '(${format.percent(h.unrealizedReturn)})',
      ),
      (l10n.depotDetailRealized, format.money(h.realizedGain, signed: true)),
      (l10n.depotDetailDividends, format.money(h.dividends)),
      if (dividendYield != null)
        (
          l10n.depotDetailDividendYield,
          format.percent(dividendYield, signed: false),
        ),
      if (frequency != null)
        (
          l10n.depotDetailDividendFrequency,
          DepotPortfolioLabels.frequency(l10n, frequency),
        ),
      if (nextExDate != null)
        (l10n.depotDetailNextExDate, '$estimated${day(nextExDate)}'),
      if (next != null)
        (l10n.depotDetailNextPayDate, '$estimated${day(next.date)}'),
      (l10n.depotHoldingTotalGain, format.money(h.totalGain, signed: true)),
      (l10n.depotKpiCosts, format.money(h.fees + h.taxes)),
      if (xirr != null) (l10n.depotKpiXirr, format.percent(xirr)),
      if (earliest != null)
        (
          l10n.depotDetailFirstActivity,
          FormatHelper.dateTime(earliest, style: DateStyle.dateOnly),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Two label/value columns only once each still has room to read.
        final columns = constraints.maxWidth >= 520 ? 2 : 1;
        final width = (constraints.maxWidth - 24 * (columns - 1)) / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 24,
              runSpacing: 6,
              children: [
                for (final (label, value) in rows)
                  SizedBox(
                    width: width,
                    child: InfoRow(label: label, value: value),
                  ),
              ],
            ),
            Wrap(
              children: [
                if (hasSales)
                  TextButton.icon(
                    onPressed: () {
                      context.read<DepotPortfolioState>().setActivityFilter(
                        DepotActivityFilter(
                          portfolioId: h.portfolioId,
                          holdingId: h.id,
                          holdingName: h.name,
                          types: const {DepotTransactionType.sell},
                        ),
                      );
                      context.read<DepotState>().setTab(DepotTab.activities);
                    },
                    icon: const Icon(Icons.sell_outlined),
                    label: Text(l10n.depotHoldingShowSales),
                  ),
                if (isin != null)
                  DepotWishlistHoldingButton(isin: isin, name: h.name),
                if (linkKind != null)
                  DepotDetailsLinkButton(holding: h, kind: linkKind),
              ],
            ),
          ],
        );
      },
    );
  }
}
