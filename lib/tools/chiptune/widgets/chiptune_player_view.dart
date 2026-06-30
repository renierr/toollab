import 'package:flutter/material.dart';

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
  final String currentVizId;
  final ValueChanged<String> onVizChanged;

  /// When set (random mode), shows the tune's modarchive.org info + link.
  final ModArchiveTune? randomTune;
  final Widget archivePanel;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback? onNext;
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
    required this.currentVizId,
    required this.onVizChanged,
    this.randomTune,
    required this.archivePanel,
    required this.onPlayPause,
    required this.onStop,
    this.onNext,
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
          ),
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
        const SizedBox(height: 8),
        ValueListenableBuilder(
          valueListenable: player.position,
          builder: (_, position, _) => ValueListenableBuilder(
            valueListenable: player.elapsed,
            builder: (_, elapsed, _) => ChiptuneSeekBar(
              position: position,
              elapsed: elapsed,
              total: player.totalDuration,
              rowsPerPattern: module.rowsPerPattern,
              totalRows: player.totalRows,
              onSeekFraction: (f) {
                final targetRow = (f * player.totalRows).floor();
                final order = (targetRow / module.rowsPerPattern).floor();
                final row = targetRow % module.rowsPerPattern;
                onSeek(order, row);
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
            onLoopChanged: onLoopChanged,
            onVolumeChanged: onVolumeChanged,
          ),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder(
          valueListenable: player.channelActivity,
          builder: (_, active, _) => ChiptuneChannelActivity(active: active),
        ),
        const SizedBox(height: 8),
        ChiptuneSampleList(module: module),
        const Divider(height: 24),
        archivePanel,
      ],
    );
  }
}
