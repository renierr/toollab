import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/data_row.dart';
import 'package:tool_lab/widgets/status_badge.dart';

import '../depot_labels.dart';
import '../models/depot_activity.dart';

class DepotActivityFields extends StatelessWidget {
  final DepotActivity activity;

  const DepotActivityFields({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            StatusBadge(
              label: DepotLabels.type(l10n, activity.type),
              color: switch (activity.type) {
                DepotActivityType.buy => AppTheme.statusBlue,
                DepotActivityType.sell => AppTheme.statusOrange,
                DepotActivityType.dividend => AppTheme.statusGreen,
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                activity.securityName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InfoRow(
          label: l10n.depotImportFieldDate,
          value: DepotLabels.date(activity.date),
        ),
        InfoRow(label: l10n.depotImportFieldIsin, value: activity.isin),
        InfoRow(
          label: l10n.depotImportFieldShares,
          value: DepotLabels.number(activity.shares, 9),
        ),
        InfoRow(
          label: l10n.depotImportFieldPrice,
          value: DepotLabels.number(activity.price, 6),
        ),
        InfoRow(
          label: l10n.depotImportFieldAmount,
          value: DepotLabels.number(activity.amount, 2),
        ),
        InfoRow(
          label: l10n.depotImportFieldTax,
          value: DepotLabels.number(activity.tax, 2),
        ),
        InfoRow(
          label: l10n.depotImportFieldFee,
          value: DepotLabels.number(activity.fee, 2),
        ),
        if (activity.isForeignCurrency && activity.fxRate != null) ...[
          const SizedBox(height: 6),
          Text(
            l10n.depotImportFxNote(
              activity.sourceCurrency,
              DepotLabels.number(activity.fxRate!, 6),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}
