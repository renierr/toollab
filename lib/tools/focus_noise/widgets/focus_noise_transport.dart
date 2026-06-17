import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/info_card.dart';

class FocusNoiseTransport extends StatelessWidget {
  final bool isPlaying;
  final String statusText;
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onTogglePlay;

  const FocusNoiseTransport({
    super.key,
    required this.isPlaying,
    required this.statusText,
    required this.volume,
    required this.onVolumeChanged,
    required this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return InfoCard(
      icon: Icons.tune,
      title: l10n.focusPlayback,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            statusText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.volume_down_outlined),
              Expanded(
                child: Slider(
                  value: volume,
                  onChanged: onVolumeChanged,
                  min: 0,
                  max: 1,
                ),
              ),
              const Icon(Icons.volume_up_outlined),
            ],
          ),
          FilledButton.icon(
            onPressed: onTogglePlay,
            icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
            label: Text(isPlaying ? l10n.focusStop : l10n.focusStart),
          ),
        ],
      ),
    );
  }
}
