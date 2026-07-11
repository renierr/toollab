import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/status_badge.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/widgets/responsive_orientation_layout.dart';

import 'config.dart';
import 'compass_state.dart';
import 'widgets/compass_dial.dart';
import 'widgets/interference_panel.dart';

class CompassPage extends StatelessWidget {
  const CompassPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CompassState>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Build the interactive dial wrapper.
    // Captures horizontal drag updates to rotate the dial when simulation is active.
    Widget buildDial() {
      Widget dial = CompassDial(
        heading: state.heading,
        pitch: state.pitch,
        roll: state.roll,
      );

      if (state.useSimulation) {
        dial = GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: (details) {
            final double delta = details.primaryDelta ?? 0.0;
            // Dragging right increases heading, dragging left decreases it
            state.adjustSimulatedHeading(-delta * 0.4);
          },
          child: dial,
        );
      }

      return dial;
    }

    // Large heading readout showing degrees and cardinal direction (e.g. 214° SW)
    Widget buildReadout() {
      final heading = state.heading;
      final direction = _getCardinalDirection(heading, l10n);

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${heading.toStringAsFixed(0)}°',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                direction,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentRed,
                ),
              ),
            ],
          ),
          if (state.useSimulation) ...[
            const SizedBox(height: 4),
            StatusBadge(
              label: state.isHardwareSupported
                  ? 'SIMULATION'
                  : 'SIMULATED (DEMO)',
              color: AppTheme.accentAmber,
              icon: Icons.science_outlined,
            ),
          ],
        ],
      );
    }

    return ToolLayout(
      title: CompassTool.config.localizedName(l10n),
      fullscreen: false,
      actions: [
        if (state.isHardwareSupported)
          IconButton(
            icon: Icon(
              state.useSimulation
                  ? Icons.sensors_off_outlined
                  : Icons.sensors_outlined,
            ),
            tooltip: state.useSimulation
                ? 'Activate Sensors'
                : 'Activate Simulation',
            onPressed: () {
              state.toggleSimulation(!state.useSimulation);
            },
          ),
      ],
      child: ResponsiveOrientationLayout(
        portrait: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              buildReadout(),
              const SizedBox(height: 8),
              buildDial(),
              if (state.useSimulation) ...[
                Text(
                  'Swipe horizontally on dial to turn',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: InterferencePanel(),
              ),
            ],
          ),
        ),
        landscape: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      buildReadout(),
                      const SizedBox(height: 8),
                      SizedBox(height: 250, child: buildDial()),
                      if (state.useSimulation)
                        Text(
                          'Swipe horizontally on dial to turn',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: theme.colorScheme.outlineVariant,
            ),
            const Expanded(
              flex: 6,
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: InterferencePanel(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCardinalDirection(double degrees, AppLocalizations l10n) {
    // Standard 8-point compass mapping
    final double d = (degrees + 22.5) % 360;
    final int index = (d / 45).floor();

    switch (index) {
      case 0:
        return 'N';
      case 1:
        return 'NE';
      case 2:
        return 'E';
      case 3:
        return 'SE';
      case 4:
        return 'S';
      case 5:
        return 'SW';
      case 6:
        return 'W';
      case 7:
        return 'NW';
      default:
        return 'N';
    }
  }
}
