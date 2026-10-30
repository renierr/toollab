import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';

import '../depot_allocation_state.dart';
import '../depot_portfolio_state.dart';
import '../models/depot_holding.dart';

class DepotAllocationSettings extends StatelessWidget {
  const DepotAllocationSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portfolio = context.watch<DepotPortfolioState>();
    final allocation = context.watch<DepotAllocationState>();
    final securities = [
      for (final holding in portfolio.holdings)
        if (!holding.isSold &&
            holding.currentValue > 0 &&
            holding.assetType == DepotAssetType.security)
          holding,
    ];
    final classified = securities
        .where((holding) => allocation.profileOf(holding) != null)
        .length;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => allocation.ensureLoaded(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionLabel(
          title: l10n.depotAllocationDataTitle,
          description: l10n.depotAllocationDataDescription,
        ),
        ListTile(
          leading: const Icon(Icons.travel_explore_outlined),
          title: Text(l10n.depotAllocationDataReload),
          subtitle: Text(
            allocation.isFetching
                ? l10n.depotAllocationDataFetching
                : l10n.depotAllocationDataCount(classified, securities.length),
          ),
          trailing: allocation.isFetching
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          onTap: allocation.isFetching || securities.isEmpty
              ? null
              : () =>
                    context.read<DepotAllocationState>().reloadAll(securities),
        ),
      ],
    );
  }
}
