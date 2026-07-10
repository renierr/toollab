import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../sound_finder_state.dart';
import 'sf_spectrum_fullscreen.dart';
import 'sf_spectrum_view.dart';

/// Compact spectrum with axis labels and an enlarge button that opens the
/// zoomable fullscreen view. Shared by the tracker and counter cards.
class SfSpectrumPanel extends StatelessWidget {
  final double height;

  const SfSpectrumPanel({super.key, this.height = 132});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<SoundFinderState>();
    final analysis = state.analysis;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: height,
        width: double.infinity,
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        child: Stack(
          children: [
            Positioned.fill(
              child: SfSpectrumView(
                magnitudes: analysis.magnitudes,
                binHz: analysis.binHz,
                peakFreqHz: state.smoothPeakHz,
                showAxes: true,
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: theme.colorScheme.surface.withValues(alpha: 0.55),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.fullscreen, size: 20),
                  tooltip: l10n.sfEnlargeSpectrum,
                  onPressed: () => SfSpectrumFullscreen.open(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
