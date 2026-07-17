import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../sound_finder_state.dart';

class SfModeTabs extends StatelessWidget {
  const SfModeTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SoundFinderState>();

    return SegmentedButton<SfMode>(
      segments: [
        ButtonSegment(
          value: SfMode.tracker,
          icon: const Icon(Icons.my_location_outlined),
          tooltip: l10n.sfTitleFinder,
        ),
        ButtonSegment(
          value: SfMode.counter,
          icon: const Icon(Icons.graphic_eq_outlined),
          tooltip: l10n.sfTitleCounter,
        ),
        ButtonSegment(
          value: SfMode.generator,
          icon: const Icon(Icons.tune_outlined),
          tooltip: l10n.sfTitleGenerator,
        ),
        ButtonSegment(
          value: SfMode.doppler,
          icon: const Icon(Icons.analytics_outlined),
          tooltip: l10n.sfTitleDoppler,
        ),
      ],
      selected: {state.mode},
      showSelectedIcon: false,
      onSelectionChanged: (selection) =>
          context.read<SoundFinderState>().setMode(selection.first),
    );
  }
}
