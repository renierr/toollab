import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/info_card.dart';
import 'package:tool_lab/widgets/status_badge.dart';

import '../chiptune_colors.dart';
import '../engine/chiptune_player.dart';
import 'chiptune_seek_bar.dart';
import 'chiptune_transport_bar.dart';
import 'chiptune_visualizer_panel.dart';

/// Simplified player layout for a natively-decoded audio file (wav/mp3/ogg/flac):
/// visualizer, time-based seek bar, transport, a small metadata card and the
/// playlist/archive panels. Tracker-specific widgets (channel LEDs, patterns,
/// sample list) are intentionally absent — they have no meaning for plain audio.
class ChiptuneAudioView extends StatelessWidget {
  final ChiptunePlayer player;
  final String fileName;
  final String format;
  final bool looping;
  final double volume;
  final bool visualizerEnabled;
  final bool animateVisualizer;
  final String currentVizId;
  final ValueChanged<String> onVizChanged;

  /// When set (playlist mode), shows the current multi-file queue.
  final Widget? playlistPanel;
  final Widget archivePanel;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback? onNext;
  final String? nextTooltip;
  final ValueChanged<bool> onLoopChanged;
  final ValueChanged<double> onVolumeChanged;

  /// Seek to a fraction (0..1) of the total duration.
  final ValueChanged<double> onSeekFraction;

  const ChiptuneAudioView({
    super.key,
    required this.player,
    required this.fileName,
    required this.format,
    required this.looping,
    required this.volume,
    required this.visualizerEnabled,
    required this.animateVisualizer,
    required this.currentVizId,
    required this.onVizChanged,
    this.playlistPanel,
    required this.archivePanel,
    required this.onPlayPause,
    required this.onStop,
    this.onNext,
    this.nextTooltip,
    required this.onLoopChanged,
    required this.onVolumeChanged,
    required this.onSeekFraction,
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
          valueListenable: player.elapsed,
          builder: (_, elapsed, _) => ChiptuneSeekBar(
            elapsed: elapsed,
            total: player.totalDuration,
            onSeekFraction: onSeekFraction,
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
        _AudioInfoCard(
          fileName: fileName,
          format: format,
          duration: player.totalDuration,
        ),
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

/// Metadata card for a native audio file: file name, format badge and duration.
class _AudioInfoCard extends StatelessWidget {
  final String fileName;
  final String format;
  final Duration duration;

  const _AudioInfoCard({
    required this.fileName,
    required this.format,
    required this.duration,
  });

  String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InfoCard(
      icon: Icons.audiotrack_outlined,
      title: fileName.isEmpty ? l10n.chipAudioFile : fileName,
      titleColor: ChiptuneColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusBadge(
            label: format.isEmpty ? l10n.chipAudioFile : format,
            color: ChiptuneColors.accent,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _Metric(
                label: l10n.chipMetricDuration,
                value: _fmtDuration(duration),
              ),
              _Metric(label: l10n.chipMetricFormat, value: format),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: ChiptuneColors.accentBright,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
