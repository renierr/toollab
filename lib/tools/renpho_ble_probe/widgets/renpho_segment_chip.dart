import 'package:flutter/material.dart';

import '../renpho_colors.dart';

/// One callout beside the figure: the segment name over its muscle and fat
/// mass, highlighted while its body part is active.
class RenphoSegmentChip extends StatelessWidget {
  final String label;
  final String muscle;
  final String fat;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  const RenphoSegmentChip({
    super.key,
    required this.label,
    required this.muscle,
    required this.fat,
    required this.color,
    required this.active,
    required this.onTap,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onHover: onHover,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: active ? 0.16 : 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? color
                  : theme.colorScheme.outline.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
              Text(
                muscle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: RenphoColors.muscle,
                ),
              ),
              Text(
                fat,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: RenphoColors.bodyFat,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
