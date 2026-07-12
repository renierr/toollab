import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_back_button.dart';
import '../emf_colors.dart';
import '../detector_state.dart';

class ScannerHeader extends StatelessWidget {
  final DetectorState state;

  const ScannerHeader({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                ToolBackButton(
                  color: Colors.white,
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                Text(
                  l10n.emfScannerTitle,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: EmfColors.neonCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l10n.emfPro,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: EmfColors.neonCyan,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              l10n.emfWallCurrentSubtitle,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),

        // Device hardware sensor / simulation status badge
        GestureDetector(
          onTap: () {
            state.setSimulationMode(!state.isSimulationActive);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: state.isSimulationActive
                  ? EmfColors.amberYellow.withValues(alpha: 0.08)
                  : EmfColors.neonEmerald.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: state.isSimulationActive
                    ? EmfColors.amberYellow.withValues(alpha: 0.4)
                    : EmfColors.neonEmerald.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state.isSimulationActive
                        ? EmfColors.amberYellow
                        : EmfColors.neonEmerald,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  state.isSimulationActive
                      ? l10n.emfSimulator
                      : l10n.emfHardwareSensor,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: state.isSimulationActive
                        ? EmfColors.amberYellow
                        : EmfColors.neonEmerald,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
