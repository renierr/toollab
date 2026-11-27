import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';

import '../models/trimz_saved_series.dart';
import '../trimz_state.dart';
import 'trimz_series_card.dart';
import 'trimz_series_page.dart';

/// A series from the viewer's history or list; [resume] shows where they are.
class TrimzSavedTile extends StatelessWidget {
  final TrimzSavedSeries saved;
  final double width;
  final bool resume;

  const TrimzSavedTile({
    super.key,
    required this.saved,
    required this.width,
    required this.resume,
  });

  Future<void> _forget(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<TrimzState>();
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.trimzRemoveFromContinue,
      message: saved.title,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.commonRemove,
    );
    if (confirmed == true) await state.forgetProgress(saved.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = saved.episodeCount;
    final progress = resume && saved.durationMs > 0
        ? (saved.positionMs / saved.durationMs).clamp(0.0, 1.0)
        : null;
    return TrimzSeriesCard(
      title: saved.title,
      posterUrl: saved.posterUrl,
      width: width,
      progress: progress,
      subtitle: resume && count > 0
          ? l10n.trimzEpisodeOf(saved.episodeIndex + 1, count)
          : count > 0
          ? l10n.trimzEpisodeCount(count)
          : null,
      onTap: () => TrimzSeriesPage.open(context, saved.toSeries()),
      onLongPress: resume ? () => unawaited(_forget(context)) : null,
    );
  }
}
