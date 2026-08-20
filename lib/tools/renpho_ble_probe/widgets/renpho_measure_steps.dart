import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../renpho_ble_probe_state.dart';

/// The two halves of a measurement, plus the result. Weighing and the handle
/// grip need different things from the user, so they get their own step rather
/// than one blanket "stand on the scale" instruction.
class RenphoMeasureSteps extends StatelessWidget {
  final RenphoMeasureStep step;

  const RenphoMeasureSteps({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stages = [
      (
        RenphoMeasureStep.weighing,
        Icons.monitor_weight_outlined,
        l10n.renphoStepWeight,
      ),
      (
        RenphoMeasureStep.impedance,
        Icons.back_hand_outlined,
        l10n.renphoStepImpedance,
      ),
      (
        RenphoMeasureStep.computing,
        Icons.insights_outlined,
        l10n.renphoStepResult,
      ),
    ];

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < stages.length; index++) ...[
              if (index > 0)
                _Connector(done: step.index > stages[index].$1.index - 1),
              Expanded(
                child: _Step(
                  icon: stages[index].$2,
                  label: stages[index].$3,
                  active: step == stages[index].$1,
                  done: step.index > stages[index].$1.index,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _hint(l10n),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: step == RenphoMeasureStep.impedance
                ? AppTheme.statusAmber
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: step == RenphoMeasureStep.impedance
                ? FontWeight.w600
                : null,
          ),
        ),
      ],
    );
  }

  String _hint(AppLocalizations l10n) => switch (step) {
    RenphoMeasureStep.waiting => l10n.renphoStatusReady,
    RenphoMeasureStep.weighing => l10n.renphoStepHintWeight,
    RenphoMeasureStep.impedance => l10n.renphoStepHintImpedance,
    RenphoMeasureStep.computing => l10n.renphoStepHintComputing,
    RenphoMeasureStep.done => l10n.renphoStatusComplete,
  };
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool done;

  const _Step({
    required this.icon,
    required this.label,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = done
        ? AppTheme.statusGreen
        : active
        ? AppTheme.accentBlue
        : theme.colorScheme.outline;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? color.withValues(alpha: 0.18) : Colors.transparent,
            border: Border.all(color: color, width: active ? 2 : 1),
          ),
          child: Icon(done ? Icons.check : icon, size: 20, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: active ? FontWeight.w700 : null,
          ),
        ),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  final bool done;

  const _Connector({required this.done});

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 2,
    margin: const EdgeInsets.only(top: 19),
    color: done
        ? AppTheme.statusGreen
        : Theme.of(context).colorScheme.outlineVariant,
  );
}
