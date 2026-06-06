import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:tool_lab/widgets/status_badge.dart';

class BatteryCard extends StatelessWidget {
  final int level;
  final BatteryState state;
  final bool isSaverMode;

  const BatteryCard({
    super.key,
    required this.level,
    required this.state,
    required this.isSaverMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCharging =
        state == BatteryState.charging || state == BatteryState.full;

    // Choose battery color based on level
    final Color color = level > 60
        ? Colors.greenAccent.shade700
        : level > 20
        ? Colors.orangeAccent.shade400
        : Colors.redAccent.shade400;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withAlpha(200),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Power Status',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isCharging
                            ? (state == BatteryState.full
                                  ? 'Fully Charged'
                                  : 'Charging')
                            : 'Discharging',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(140),
                        ),
                      ),
                    ],
                  ),
                  if (isSaverMode)
                    StatusBadge(
                      label: 'Saver Active',
                      color: Colors.orange,
                      icon: Icons.energy_savings_leaf,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$level%',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: color,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _BatteryIndicator(
                          level: level,
                          isCharging: isCharging,
                          color: color,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCharging
                          ? Icons.power_outlined
                          : (level > 20
                                ? Icons.battery_std
                                : Icons.battery_alert),
                      size: 32,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatteryIndicator extends StatelessWidget {
  final int level;
  final bool isCharging;
  final Color color;

  const _BatteryIndicator({
    required this.level,
    required this.isCharging,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            border: Border.all(color: color.withAlpha(200), width: 2.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: level / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      gradient: LinearGradient(
                        colors: [color, color.withAlpha(160)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                if (isCharging)
                  const Center(
                    child: Icon(
                      Icons.bolt,
                      color: Colors.white,
                      size: 22,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 1.5),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        Container(
          width: 4.5,
          height: 12,
          decoration: BoxDecoration(
            color: color.withAlpha(200),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(2.5),
              bottomRight: Radius.circular(2.5),
            ),
          ),
        ),
      ],
    );
  }
}
