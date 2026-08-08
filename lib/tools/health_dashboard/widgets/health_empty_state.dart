import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import 'health_dashboard_settings_page.dart';

class HealthEmptyState extends StatelessWidget {
  final IconData icon;
  final String? title;
  final String? message;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  const HealthEmptyState({
    super.key,
    this.icon = Icons.health_and_safety_outlined,
    this.title,
    this.message,
    this.buttonLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final displayTitle = title ?? l10n.healthDashboardNoData;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              displayTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.7,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed:
                  onPressed ??
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HealthDashboardSettingsPage(),
                    ),
                  ),
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: Text(buttonLabel ?? l10n.healthDashboardSettings),
            ),
          ],
        ),
      ),
    );
  }
}
