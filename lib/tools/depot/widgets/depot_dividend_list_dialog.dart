import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../depot_format.dart';
import '../dividends/depot_dividend_calendar.dart';
import 'depot_dividend_entry_tile.dart';

/// The payments behind one dividend figure; each opens its details.
class DepotDividendListDialog extends StatelessWidget {
  final String title;
  final List<DepotDividendEntry> entries;
  final DepotFormat format;

  const DepotDividendListDialog({
    super.key,
    required this.title,
    required this.entries,
    required this.format,
  });

  /// Past payments come newest first, expected ones soonest first.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<DepotDividendEntry> entries,
    required DepotFormat format,
    bool newestFirst = true,
  }) => showDialog<void>(
    context: context,
    builder: (_) => DepotDividendListDialog(
      title: title,
      entries: newestFirst ? entries.reversed.toList() : entries,
      format: format,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final total = entries.fold<double>(0, (sum, e) => sum + e.net);
    // A dialog sizes against the window, not a pane.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.6;

    return ResponsiveAlertDialog(
      title: Text(title),
      content: SelectionArea(
        child: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.depotDividendListSummary(
                  entries.length,
                  format.money(total),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    l10n.depotDividendListEmpty,
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    itemBuilder: (context, index) => DepotDividendEntryTile(
                      entry: entries[index],
                      format: format,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}
