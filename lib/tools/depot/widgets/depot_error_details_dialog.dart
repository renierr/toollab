import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import 'package:tool_lab/widgets/selectable_text_view.dart';

import '../depot_portfolio_labels.dart';
import '../parqet/parqet_exception.dart';

class DepotErrorDetailsDialog extends StatelessWidget {
  final ParqetException error;

  const DepotErrorDetailsDialog({super.key, required this.error});

  static Future<void> show(BuildContext context, ParqetException error) =>
      showDialog<void>(
        context: context,
        builder: (_) => DepotErrorDetailsDialog(error: error),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final retryAfter = error.retryAfter;

    return ResponsiveAlertDialog(
      title: Text(l10n.depotErrorDetailsTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              DepotPortfolioLabels.error(l10n, error),
              style: theme.textTheme.bodyMedium,
            ),
            if (retryAfter != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.depotErrorRetryAfter(retryAfter.inSeconds),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            SelectableTextView(
              text: error.toString(),
              emptyMessage: l10n.depotErrorDetailsEmpty,
              maxHeight: 240,
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _copy(context),
          icon: const Icon(Icons.copy_outlined),
          label: Text(l10n.commonCopy),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }

  Future<void> _copy(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final retryAfter = error.retryAfter;
    final text = [
      DepotPortfolioLabels.error(l10n, error),
      if (retryAfter != null) l10n.depotErrorRetryAfter(retryAfter.inSeconds),
      '',
      error.toString(),
    ].join('\n');
    await ClipboardHelper.setText(text);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.depotErrorDetailsCopied)));
  }
}
