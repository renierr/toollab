import 'package:flutter/material.dart';

import 'chiptune_circular_viz.dart';
import 'chiptune_mirrored_bars_viz.dart';
import 'chiptune_particles_viz.dart';
import 'chiptune_pulse_grid_viz.dart';
import 'chiptune_spectrum_viz.dart';
import 'chiptune_viz_data.dart';
import 'chiptune_waveform_viz.dart';

/// Metadata + factory for a single chiptune visualization.
class VizDefinition {
  final String id;
  final String label;
  final IconData icon;
  final Widget Function({VizData? data, Key? key}) create;

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
      create: ({VizData? data, Key? key}) =>
          ChiptuneSpectrumViz(key: key, data: data),
    ),
    VizDefinition(
      id: 'waveform',
      label: 'Waveform',
      icon: Icons.show_chart,
      create: ({VizData? data, Key? key}) =>
          ChiptuneWaveformViz(key: key, data: data),
    ),
    VizDefinition(
      id: 'pulse-grid',
      label: 'Pulse Grid',
      icon: Icons.grid_on,
      create: ({VizData? data, Key? key}) =>
          ChiptunePulseGridViz(key: key, data: data),
    ),
    VizDefinition(
      id: 'circular',
      label: 'Circular',
      icon: Icons.donut_large_outlined,
      create: ({VizData? data, Key? key}) =>
          ChiptuneCircularViz(key: key, data: data),
    ),
    VizDefinition(
      id: 'mirrored-bars',
      label: 'Mirrored Bars',
      icon: Icons.flip_to_front,
      create: ({VizData? data, Key? key}) =>
          ChiptuneMirroredBarsViz(key: key, data: data),
    ),
    VizDefinition(
      id: 'particles',
      label: 'Particles',
      icon: Icons.blur_on,
      create: ({VizData? data, Key? key}) =>
          ChiptuneParticlesViz(key: key, data: data),
    ),
  ];

  static String get defaultId => all.first.id;

  static int indexForId(String id) {
    final i = all.indexWhere((v) => v.id == id);
    return i >= 0 ? i : 0;
  }
}
