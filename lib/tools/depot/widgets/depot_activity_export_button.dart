import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_activity_export.dart';
import '../depot_portfolio_state.dart';

class DepotActivityExportButton extends StatelessWidget {
  const DepotActivityExportButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<DepotPortfolioState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: state.visibleTransactions.isEmpty
              ? null
              : () {
                  final transactions = context
                      .read<DepotPortfolioState>()
                      .visibleTransactions;
                  FileSaveHelper.saveFile(
                    context: context,
                    suggestedName: 'depot-activities.csv',
                    bytes: DepotActivityExport.csv(transactions),
                    successMessageAndroid: l10n.depotExportDone,
                    successMessageGeneralBuilder: (path) =>
                        '${l10n.depotExportDone}\n$path',
                    errorMessageBuilder: (error) =>
                        '${l10n.depotTaxExportFailed}: $error',
                  );
                },
          icon: const Icon(Icons.download_outlined),
          label: Text(l10n.depotActivitiesExport),
        ),
        Text(
          l10n.depotActivitiesExportNote,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
        ),
      ],
    );
  }
}
