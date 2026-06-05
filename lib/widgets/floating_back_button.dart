import 'package:flutter/material.dart';

/// A premium, floating circular back button that can be positioned
/// in full-screen pages to save vertical space.
class FloatingBackButton extends StatelessWidget {
  const FloatingBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Navigator.of(context).canPop()) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withAlpha(200),
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
        tooltip: 'Back',
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
