import 'package:flutter/material.dart';

class BubbleLevelStatus extends StatelessWidget {
  final bool locked;
  final String message;
  final bool isError;

  const BubbleLevelStatus({
    super.key,
    required this.locked,
    this.message = '',
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: locked
                    ? theme.colorScheme.primary.withAlpha(25)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: locked
                      ? theme.colorScheme.primary.withAlpha(80)
                      : theme.colorScheme.onSurface.withAlpha(40),
                ),
              ),
              child: Text(
                locked ? 'Level Locked' : 'Unstable',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: locked
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withAlpha(120),
                ),
              ),
            ),
          ],
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isError
                  ? theme.colorScheme.error.withAlpha(15)
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: isError
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
