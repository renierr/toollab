import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../drift_bloom_colors.dart';

class DriftBloomHelpPage extends StatelessWidget {
  const DriftBloomHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = [
      (
        Icons.touch_app_outlined,
        l10n.driftBloomHelpSteer,
        l10n.driftBloomHelpSteerText,
        _HelpVisual.steer,
      ),
      (
        Icons.radio_button_unchecked,
        l10n.driftBloomHelpRings,
        l10n.driftBloomHelpRingsText,
        _HelpVisual.rings,
      ),
      (
        Icons.local_florist_outlined,
        l10n.driftBloomHelpBloom,
        l10n.driftBloomHelpBloomText,
        _HelpVisual.bloom,
      ),
      (
        Icons.bolt_outlined,
        l10n.driftBloomHelpCombo,
        l10n.driftBloomHelpComboText,
        _HelpVisual.combo,
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.driftBloomHelpTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l10n.driftBloomGoal,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          for (final step in steps)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          step.$1,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            step.$2,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(child: _HelpDiagram(type: step.$4)),
                    const SizedBox(height: 12),
                    Text(step.$3),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _HelpVisual { steer, rings, bloom, combo }

class _HelpDiagram extends StatelessWidget {
  final _HelpVisual type;

  const _HelpDiagram({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 190,
      height: 82,
      child: Stack(
        children: [
          if (type == _HelpVisual.steer) ...[
            const Positioned(
              left: 30,
              top: 30,
              child: _Dot(color: DriftBloomColors.seed),
            ),
            Positioned(
              left: 78,
              top: 16,
              child: Icon(Icons.arrow_forward_rounded, color: color),
            ),
            Positioned(
              left: 130,
              top: 22,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: DriftBloomColors.ring, width: 2),
                ),
              ),
            ),
          ],
          if (type == _HelpVisual.rings)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: DriftBloomColors.ring.withValues(alpha: 0.8),
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          if (type == _HelpVisual.rings)
            const Positioned(
              left: 81,
              top: 27,
              child: _Dot(color: DriftBloomColors.ringInner),
            ),
          if (type == _HelpVisual.bloom)
            for (final offset in const [
              Offset(84, 8),
              Offset(122, 30),
              Offset(84, 52),
              Offset(46, 52),
              Offset(8, 30),
              Offset(46, 8),
            ])
              Positioned(
                left: offset.dx,
                top: offset.dy,
                child: const _Dot(color: DriftBloomColors.petal),
              ),
          if (type == _HelpVisual.bloom)
            const Positioned(
              left: 84,
              top: 30,
              child: _Dot(color: DriftBloomColors.seed),
            ),
          if (type == _HelpVisual.combo)
            const Positioned(
              left: 71,
              top: 25,
              child: Text(
                'x3',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 30),
              ),
            ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;

  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
