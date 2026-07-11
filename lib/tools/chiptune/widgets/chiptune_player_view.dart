import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../chiptune_colors.dart';
import '../collection_service.dart';
import '../engine/chiptune_player.dart';
import '../engine/module.dart';
import '../modarchive_service.dart';
import 'chiptune_channel_activity.dart';
import 'chiptune_modarchive_info.dart';
import 'chiptune_module_info.dart';
import 'chiptune_sample_list.dart';
import 'chiptune_seek_bar.dart';
import 'chiptune_transport_bar.dart';
import 'chiptune_visualizer_panel.dart';

/// Full player layout for a loaded module: visualizer, metadata, transport,
/// seek bar, channel LEDs, sample list and the archive panel.
class ChiptunePlayerView extends StatelessWidget {
  final ChiptunePlayer player;
  final ModuleFile module;
  final bool looping;
  final double volume;
  final bool visualizerEnabled;
  final bool animateVisualizer;
  final String currentVizId;
  final ValueChanged<String> onVizChanged;

  /// When set (random mode), shows the tune's modarchive.org info + link.
  final ModArchiveTune? randomTune;

  /// When set (server random mode), shows the collection tune's info.
  final CollectionTune? serverTune;

  /// When set (playlist mode), shows the current multi-file queue.
  final Widget? playlistPanel;
  final Widget archivePanel;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback? onNext;
  final String? nextTooltip;
  final ValueChanged<bool> onLoopChanged;
  final ValueChanged<double> onVolumeChanged;
  final void Function(int order, int row) onSeek;

  const ChiptunePlayerView({
    super.key,
    required this.player,
    required this.module,
    required this.looping,
    required this.volume,
    required this.visualizerEnabled,
    required this.animateVisualizer,
    required this.currentVizId,
    required this.onVizChanged,
    this.randomTune,
    this.serverTune,
    this.playlistPanel,
    required this.archivePanel,
    required this.onPlayPause,
    required this.onStop,
    this.onNext,
    this.nextTooltip,
    required this.onLoopChanged,
    required this.onVolumeChanged,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (visualizerEnabled)
          ChiptuneVisualizerPanel(
            player: player,
            currentVizId: currentVizId,
            onVizChanged: onVizChanged,
            animate: animateVisualizer,
          ),
        ValueListenableBuilder(
          valueListenable: player.position,
          builder: (_, position, _) => ValueListenableBuilder(
            valueListenable: player.elapsed,
            builder: (_, elapsed, _) => ChiptuneSeekBar(
              position: position,
              elapsed: elapsed,
              total: player.totalDuration,
              onSeekFraction: (f) {
                final targetRow = (f * player.totalRows).round().clamp(
                  0,
                  player.totalRows,
                );
                int accumulated = 0;
                for (int o = 0; o < module.sequence.length; o++) {
                  final patIdx = module.sequence[o];
                  final rowCount =
                      (patIdx >= 0 && patIdx < module.patterns.length)
                      ? module.patterns[patIdx].rows.length
                      : 0;
                  if (accumulated + rowCount > targetRow) {
                    onSeek(o, targetRow - accumulated);
                    return;
                  }
                  accumulated += rowCount;
                }
                if (module.sequence.isNotEmpty) {
                  final lastOrder = module.sequence.length - 1;
                  final patIdx = module.sequence.last;
                  final lastRow =
                      (patIdx >= 0 && patIdx < module.patterns.length)
                      ? module.patterns[patIdx].rows.length - 1
                      : 0;
                  onSeek(lastOrder, lastRow);
                }
              },
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: player.state,
          builder: (_, state, _) => ChiptuneTransportBar(
            isPlaying: state == ChiptunePlaybackState.playing,
            looping: looping,
            volume: volume,
            onPlayPause: onPlayPause,
            onStop: onStop,
            onNext: onNext,
            nextTooltip: nextTooltip,
            onLoopChanged: onLoopChanged,
            onVolumeChanged: onVolumeChanged,
          ),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder(
          valueListenable: player.channelActivity,
          builder: (_, active, _) => ChiptuneChannelActivity(active: active),
        ),
        const SizedBox(height: 12),
        ChiptuneModuleInfo(module: module),
        if (randomTune != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ChiptuneModArchiveInfo(tune: randomTune!),
          ),
        ],
        if (serverTune != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _ChiptuneCollectionInfo(tune: serverTune!),
          ),
        ],
        const SizedBox(height: 8),
        ChiptuneSampleList(module: module),
        if (playlistPanel != null) ...[
          const Divider(height: 24),
          playlistPanel!,
        ],
        const Divider(height: 24),
        archivePanel,
      ],
    );
  }
}

/// Info card for a collection (own server) tune — shows title, file name,
/// format and source label.
class _ChiptuneCollectionInfo extends StatelessWidget {
  final CollectionTune tune;

  const _ChiptuneCollectionInfo({required this.tune});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tune.title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: ChiptuneColors.accentBright,
          ),
        ),
        Text(
          tune.fileName,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChiptuneDetailChip(
              label: l10n.chipMetricFormat,
              value: tune.format,
            ),
            ChiptuneDetailChip(
              label: l10n.chipRandomSourceLabel,
              value: l10n.chipRandomSourceServer,
            ),
          ],
        ),
      ],
    );
  }
}
