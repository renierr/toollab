import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../config.dart';

class PaperlessNotConfigured extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const PaperlessNotConfigured({super.key, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PaperlessTool.config.icon,
                size: 64,
                color: PaperlessTool.config.accentColor,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.paperlessNotConfiguredTitle,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.paperlessNotConfiguredBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.link),
                label: Text(l10n.paperlessConnect),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
