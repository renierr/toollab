import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';

import '../depot_dividend_state.dart';
import '../depot_portfolio_state.dart';

class DepotDividendSettings extends StatelessWidget {
  const DepotDividendSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portfolio = context.watch<DepotPortfolioState>();
    final dividends = context.watch<DepotDividendState>();
    final fetchedAt = dividends.fetchedAt;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => dividends.ensureLoaded(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionLabel(
          title: l10n.depotDividendDataTitle,
          description: l10n.depotDividendDataDescription,
        ),
        ListTile(
          leading: const Icon(Icons.event_repeat_outlined),
          title: Text(l10n.depotDividendRefresh),
          subtitle: Text(
            dividends.isFetching
                ? l10n.depotDividendDataFetching
                : fetchedAt == null
                ? l10n.depotDividendSourceNever
                : l10n.depotDividendSource(FormatHelper.dateTime(fetchedAt)),
          ),
          trailing: dividends.isFetching
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          onTap: dividends.isFetching || portfolio.holdings.isEmpty
              ? null
              : () => context.read<DepotDividendState>().refresh(
                  holdings: portfolio.holdings,
                  currency: portfolio.currency,
                  force: true,
                ),
        ),
      ],
    );
  }
}
