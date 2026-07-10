import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/info_card.dart';

import '../sf_format.dart';
import '../sound_finder_colors.dart';
import '../sound_finder_state.dart';
import 'sf_level_meter.dart';
import 'sf_permission_notice.dart';
import 'sf_readout.dart';
import 'sf_spectrum_panel.dart';

class SfTrackerView extends StatelessWidget {
  const SfTrackerView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SoundFinderState>();

    if (state.micStatus != MicStatus.running) {
      return SfPermissionNotice(status: state.micStatus);
    }

    final (String guidance, Color color, IconData icon) = switch (state.trend) {
      TrackerTrend.hotter => (
        l10n.sfGuidanceHotter,
        SoundFinderColors.hot,
        Icons.local_fire_department_outlined,
      ),
      TrackerTrend.colder => (
        l10n.sfGuidanceColder,
        SoundFinderColors.cold,
        Icons.ac_unit_outlined,
      ),
      TrackerTrend.steady => (
        l10n.sfGuidanceSteady,
        Theme.of(context).colorScheme.primary,
        Icons.trending_flat_outlined,
      ),
      TrackerTrend.silent => (
        l10n.sfGuidanceSilent,
        Theme.of(context).colorScheme.onSurfaceVariant,
        Icons.volume_off_outlined,
      ),
    };

    final double? refDelta = state.referenceDelta;
    final double peakNorm = ((state.peakHoldDb + 70) / 70).clamp(0.0, 1.0);
    final double? refNorm = state.referenceDb == null
        ? null
        : ((state.referenceDb! + 70) / 70).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoCard(
          icon: Icons.my_location_outlined,
          title: l10n.sfTrackerTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      guidance,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SfLevelMeter(
                levelNorm: state.levelNorm,
                peakNorm: peakNorm,
                referenceNorm: refNorm,
                fillColor: color,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SfReadout(
                    label: l10n.sfLevel,
                    value: '${state.smoothDb.toStringAsFixed(0)} dB',
                  ),
                  SfReadout(
                    label: l10n.sfDominant,
                    value: formatHz(state.smoothPeakHz),
                    valueColor: color,
                  ),
                  SfReadout(
                    label: l10n.sfPeakHold,
                    value: '${state.peakHoldDb.toStringAsFixed(0)} dB',
                  ),
                ],
              ),
              if (refDelta != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${refDelta >= 0 ? '+' : ''}${refDelta.toStringAsFixed(1)} dB ${l10n.sfVsReference}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.read<SoundFinderState>().markReference(),
                    icon: const Icon(Icons.push_pin_outlined),
                    label: Text(l10n.sfSetReference),
                  ),
                  if (state.referenceDb != null)
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.read<SoundFinderState>().clearReference(),
                      icon: const Icon(Icons.close),
                      label: Text(l10n.sfClearReference),
                    ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.read<SoundFinderState>().resetPeakHold(),
                    icon: const Icon(Icons.refresh_outlined),
                    label: Text(l10n.sfResetPeak),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.graphic_eq_outlined,
          title: l10n.sfSpectrum,
          child: const SfSpectrumPanel(),
        ),
      ],
    );
  }
}
