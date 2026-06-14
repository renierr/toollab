import 'package:flutter/material.dart';

import 'chiptune_spectrum_viz.dart';
import 'chiptune_waveform_viz.dart';

/// Metadata + factory for a single chiptune visualization.
class VizDefinition {
  final String id;
  final String label;
  final IconData icon;
  final Widget Function({required bool active, Key? key}) create;

  const VizDefinition({
    required this.id,
    required this.label,
    required this.icon,
    required this.create,
  });
}

/// Central registry of all available visualizations.
/// Add a new [VizDefinition] to [all] to register it — no other changes needed.
class ChiptuneVizRegistry {
  ChiptuneVizRegistry._();

  static final List<VizDefinition> all = [
    VizDefinition(
      id: 'spectrum',
      label: 'Spectrum',
      icon: Icons.equalizer,
      create: ({bool active = true, Key? key}) =>
          ChiptuneSpectrumViz(key: key, active: active),
    ),
    VizDefinition(
      id: 'waveform',
      label: 'Waveform',
      icon: Icons.show_chart,
      create: ({bool active = true, Key? key}) =>
          ChiptuneWaveformViz(key: key, active: active),
    ),
  ];

  static String get defaultId => all.first.id;

  static int indexForId(String id) {
    final i = all.indexWhere((v) => v.id == id);
    return i >= 0 ? i : 0;
  }
}
