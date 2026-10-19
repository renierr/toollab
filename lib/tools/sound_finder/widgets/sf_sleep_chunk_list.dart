import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../audio/sleep_chunk_analyzer.dart';
import '../sleep_labels.dart';
import '../sleep_player.dart';
import '../sleep_session_data.dart';
import '../sleep_session_store.dart';
import '../sleep_sessions_state.dart';

/// Collapsed by default and paged, since a night can hold hundreds of chunks.
class SfSleepChunkList extends StatefulWidget {
  const SfSleepChunkList({super.key, required this.session});

  final SleepSession session;

  @override
  State<SfSleepChunkList> createState() => _SfSleepChunkListState();
}

class _SfSleepChunkListState extends State<SfSleepChunkList> {
  static const _page = 50;

  bool _expanded = false;
  int _limit = _page;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = widget.session;
    final (_, selected) = context
        .select<SleepSessionsState, (Set<SleepSoundCategory?>, int?)>(
          (s) => (s.filter(session.id), s.selectedIndex(session.id)),
        );
    final (playing, queueActive) = context.select<SleepPlayer, (int?, bool)>(
      (p) => (p.playingIndex(session.id), p.isQueueActive(session.id)),
    );
    final visible = context.read<SleepSessionsState>().visibleIndices(session);
    final shown = visible.take(_limit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.list_alt_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.sfSleepChunkList(visible.length),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          for (final i in shown)
            _ChunkRow(
              session: session,
              index: i,
              event: session.data.events[i],
              selected: i == selected,
              playing: i == playing,
              playingSingle: i == playing && !queueActive,
            ),
          if (visible.length > shown.length)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _limit += _page),
                child: Text(
                  l10n.sfSleepShowMore(
                    (visible.length - shown.length).clamp(0, _page),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ChunkRow extends StatelessWidget {
  const _ChunkRow({
    required this.session,
    required this.index,
    required this.event,
    required this.selected,
    required this.playing,
    required this.playingSingle,
  });

  final SleepSession session;
  final int index;
  final SleepEvent event;
  final bool selected;
  final bool playing;

  /// Played on its own via the row button, so the button stops it.
  final bool playingSingle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final category = event.analysis?.category;
    final details = [
      category.label(l10n),
      '${event.peakDb.toStringAsFixed(1)} dB',
      sleepDuration(event.duration),
      if (event.annotation != null) event.annotation!,
    ].join(' · ');

    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: category.color.withValues(alpha: 0.2),
        child: playing
            ? Icon(Icons.graphic_eq, size: 16, color: category.color)
            : Icon(category.icon, size: 16, color: category.color),
      ),
      title: Text(
        '#${index + 1}  ${sleepClock(event.startedAt)} – ${sleepClock(event.endedAt)}',
        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      ),
      subtitle: Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        tooltip: playingSingle
            ? l10n.sfSleepStopPlayback
            : l10n.sfSleepPlayChunk,
        icon: Icon(playingSingle ? Icons.stop : Icons.play_arrow),
        onPressed: session.hasFile(event)
            ? () => context.read<SleepPlayer>().playChunk(session, index)
            : null,
      ),
      onTap: () => context.read<SleepSessionsState>().select(session, index),
    );
  }
}
