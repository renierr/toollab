import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/x_post.dart';

/// Stands in for a post marked "Not interested", like x.com's collapsed row.
class XNotInterestedNotice extends StatelessWidget {
  final XFeedback feedback;
  final VoidCallback onUndo;

  const XNotInterestedNotice({
    super.key,
    required this.feedback,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Text(
            feedback.confirmation ?? l10n.xFeedNotInterestedDone,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (feedback.canUndo)
            ExcludeFocus(
              child: TextButton(onPressed: onUndo, child: Text(l10n.xFeedUndo)),
            ),
        ],
      ),
    );
  }
}
