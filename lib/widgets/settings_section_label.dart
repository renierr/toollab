import 'package:flutter/material.dart';

/// Group label for a run of settings tiles, with an optional line explaining
/// what the group is for.
class SettingsSectionLabel extends StatelessWidget {
  final String title;
  final String? description;

  const SettingsSectionLabel({
    required this.title,
    this.description,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
