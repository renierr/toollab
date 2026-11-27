import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// A centered note, with a retry button when [onRetry] is set.
class TrimzMessageView extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  const TrimzMessageView({
    super.key,
    required this.icon,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context).commonRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
