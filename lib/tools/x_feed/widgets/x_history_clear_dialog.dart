import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../x_feed_state.dart';
import '../x_video_history.dart';

/// Picks how old an entry must be to go, then removes those entries.
class XHistoryClearDialog extends StatelessWidget {
  const XHistoryClearDialog({super.key});

  static Future<void> show(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final history = context.read<XFeedState>().history;
    final choice = await showDialog<_Choice>(
      context: context,
      builder: (_) => const XHistoryClearDialog(),
    );
    if (choice == null) return;
    final removed = await history.clearOlderThan(choice.age);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.xFeedHistoryCleared(removed))),
    );
  }

  static String label(AppLocalizations l10n, Duration? age) => switch (age) {
    null => l10n.xFeedHistoryClearAll,
    final d when d.inDays >= 365 => l10n.xFeedHistoryOlderThanYears(
      d.inDays ~/ 365,
    ),
    final d when d.inDays >= 30 => l10n.xFeedHistoryOlderThanMonths(
      d.inDays ~/ 30,
    ),
    final d => l10n.xFeedHistoryOlderThanDays(d.inDays),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      title: Text(l10n.xFeedHistoryClear),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final age in XVideoHistory.clearOptions)
            ListTile(
              leading: Icon(
                age == null ? Icons.delete_forever_outlined : Icons.history,
              ),
              title: Text(label(l10n, age)),
              onTap: () => Navigator.of(context).pop(_Choice(age)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}

/// Wraps the age so "everything" (null) differs from a dismissed dialog.
class _Choice {
  final Duration? age;

  const _Choice(this.age);
}
