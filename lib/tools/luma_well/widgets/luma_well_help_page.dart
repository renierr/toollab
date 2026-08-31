import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class LumaWellHelpPage extends StatelessWidget {
  const LumaWellHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = [
      (
        Icons.touch_app_outlined,
        l10n.lumaWellHelpCapture,
        l10n.lumaWellHelpCaptureText,
        _HelpVisual.capture,
      ),
      (
        Icons.timer_outlined,
        l10n.lumaWellHelpHold,
        l10n.lumaWellHelpHoldText,
        _HelpVisual.hold,
      ),
      (
        Icons.public_outlined,
        l10n.lumaWellHelpGrow,
        l10n.lumaWellHelpGrowText,
        _HelpVisual.grow,
      ),
      (
        Icons.auto_awesome_outlined,
        l10n.lumaWellHelpChallenge,
        l10n.lumaWellHelpChallengeText,
        _HelpVisual.challenge,
      ),
      (
        Icons.star_rounded,
        l10n.lumaWellHelpPowerOrb,
        l10n.lumaWellHelpPowerOrbText,
        _HelpVisual.power,
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.lumaWellHelpTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l10n.lumaWellGoal,
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
                        Text(
                          step.$2,
                          style: Theme.of(context).textTheme.titleMedium,
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

enum _HelpVisual { capture, hold, grow, challenge, power }

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
          if (type == _HelpVisual.capture || type == _HelpVisual.hold)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: color.withValues(alpha: 0.7),
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          for (final offset in const [
            Offset(54, 27),
            Offset(91, 43),
            Offset(72, 61),
          ])
            Positioned(
              left: offset.dx,
              top: offset.dy,
              child: _Dot(color: color),
            ),
          if (type == _HelpVisual.hold)
            const Positioned(
              right: 8,
              top: 22,
              child: Text("2s", style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          if (type == _HelpVisual.grow) ...[
            const Positioned(
              left: 20,
              top: 30,
              child: _Dot(color: Color(0xFFFFA52E)),
            ),
            Positioned(
              left: 78,
              top: 16,
              child: Icon(Icons.arrow_forward_rounded, color: color),
            ),
            Positioned(
              right: 22,
              top: 11,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
          if (type == _HelpVisual.challenge)
            for (var index = 0; index < 12; index++)
              Positioned(
                left: 20 + (index % 6) * 28.0,
                top: 10 + (index ~/ 6) * 40.0,
                child: _Dot(color: index.isEven ? color : Colors.orange),
              ),
          if (type == _HelpVisual.power) ...[
            const Positioned(
              left: 40,
              top: 28,
              child: _Dot(color: Color(0xFFFFA52E)),
            ),
            const Positioned(
              left: 90,
              top: 28,
              child: Icon(
                Icons.star_rounded,
                color: Color(0xFFFFD26A),
                size: 28,
              ),
            ),
            const Positioned(
              left: 138,
              top: 28,
              child: _Dot(color: Color(0xFFE04E8A)),
            ),
          ],
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
