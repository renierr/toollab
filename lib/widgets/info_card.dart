import 'package:flutter/material.dart';

class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Color? titleColor;
  final Color? backgroundColor;
  final Color? borderColor;

  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.titleColor,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finalBgColor =
        backgroundColor ??
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
    final finalBorderColor =
        borderColor ?? theme.colorScheme.outline.withValues(alpha: 0.15);

    return Card(
      elevation: 0,
      color: finalBgColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: finalBorderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: titleColor ?? theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
