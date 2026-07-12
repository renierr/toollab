import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/tool_back_button.dart';

/// A premium, floating circular back button that can be positioned
/// in full-screen pages to save vertical space.
class FloatingBackButton extends StatelessWidget {
  const FloatingBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withAlpha(200),
      shape: const CircleBorder(),
      elevation: 2,
      child: const ToolBackButton(visualDensity: VisualDensity.compact),
    );
  }
}
