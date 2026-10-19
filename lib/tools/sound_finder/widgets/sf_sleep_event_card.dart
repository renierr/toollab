import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../sleep_labels.dart';
import '../sleep_session_store.dart';
import '../sleep_sessions_state.dart';
import 'sf_sleep_annotation_dialog.dart';

/// Details and actions for the chunk selected in the timeline.
class SfSleepEventCard extends StatelessWidget {
  const SfSleepEventCard({super.key, required this.session});

  final SleepSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<SleepSessionsState>();
    final events = session.data.events;
    final index = state.selectedIndex(session.id);
    if (index == null || index >= events.length) return const SizedBox.shrink();
    final e = events[index];
    final a = e.analysis;
    final category = a?.category;
    final hasFile = session.hasFile(e);
    final playing = state.isPlayingChunk(session.id, index);
    final size = session.sizeOf(e);

    final facts = <String>[
      '${l10n.sfSleepPeak} ${e.peakDb.toStringAsFixed(1)} dB',
      if (a != null) ...[
        '${l10n.sfSleepActive} ${(a.activeMs / 1000).toStringAsFixed(1)} s',
        '${l10n.sfSleepBursts} ${a.bursts}',
        '${l10n.sfSleepDominant} ${a.dominantHz.round()} Hz',
        if (a.periodicity > 0.35)
          l10n.sfSleepRhythm(a.periodSec.toStringAsFixed(1)),
      ],
      if (size != null) FormatHelper.fileSize(size),
    ];

    return Card(
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: category.color.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(category.icon, color: category.color, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    a == null
                        ? category.label(l10n)
                        : '${category.label(l10n)} · '
                              '${l10n.sfSleepConfidence((a.confidence * 100).round())}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  l10n.sfSleepChunkOf(index + 1, events.length),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${sleepClock(e.startedAt)} – ${sleepClock(e.endedAt)} · '
              '${sleepDuration(e.duration)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(facts.join(' · '), style: theme.textTheme.bodySmall),
            Text(
              e.fileName,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (e.annotation != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  e.annotation!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (!hasFile)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.sfSleepFileMissing,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: l10n.sfSleepPrevChunk,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => state.step(session, -1),
                ),
                IconButton.filledTonal(
                  tooltip: playing
                      ? l10n.sfSleepStopPlayback
                      : l10n.sfSleepPlayChunk,
                  icon: Icon(playing ? Icons.stop : Icons.play_arrow),
                  onPressed: hasFile
                      ? () => state.playChunk(session, index)
                      : null,
                ),
                IconButton(
                  tooltip: l10n.sfSleepNextChunk,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => state.step(session, 1),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.playlist_play),
                  label: Text(l10n.sfSleepPlayFromHere),
                  onPressed: () => state.playAll(session, from: index),
                ),
                IconButton(
                  tooltip: l10n.sfSleepAnnotate,
                  icon: const Icon(Icons.edit_note_outlined),
                  onPressed: () async {
                    final text = await SfSleepAnnotationDialog.show(
                      context,
                      initial: e.annotation,
                    );
                    if (text != null) await state.annotate(session, e, text);
                  },
                ),
                IconButton(
                  tooltip: l10n.sfSleepSaveChunk,
                  icon: const Icon(Icons.save_alt_outlined),
                  onPressed: hasFile
                      ? () => FileSaveHelper.saveFileFromPath(
                          context: context,
                          suggestedName: e.fileName,
                          sourcePath: session.data.fileFor(e).path,
                        )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
