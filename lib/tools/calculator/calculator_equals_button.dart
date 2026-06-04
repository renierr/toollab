import 'package:flutter/material.dart';

class CalculatorEqualsButton extends StatelessWidget {
  final VoidCallback onTap;

  const CalculatorEqualsButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 8),
      child: SizedBox(
        height: 56,
        child: Material(
          color: theme.colorScheme.tertiary,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Center(
              child: Text(
                '=',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onTertiary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
