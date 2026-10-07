import 'package:flutter/material.dart';

import '../models/paperless_label.dart';

/// A tag in the colors the user picked for it in Paperless.
class PaperlessTagChip extends StatelessWidget {
  final PaperlessLabel tag;

  const PaperlessTagChip({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = tag.color ?? theme.colorScheme.secondaryContainer;
    final foreground = tag.color == null
        ? theme.colorScheme.onSecondaryContainer
        : ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        tag.name,
        style: theme.textTheme.labelSmall?.copyWith(color: foreground),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class PaperlessTagDot extends StatelessWidget {
  final Color? color;

  const PaperlessTagDot({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.secondary,
        shape: BoxShape.circle,
      ),
    );
  }
}
