import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../api/x_api.dart';

class XErrorView extends StatelessWidget {
  final XApiException error;
  final VoidCallback onRetry;
  final bool compact;

  const XErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    this.compact = false,
  });

  static String message(AppLocalizations l10n, XApiException error) =>
      switch (error.kind) {
        XApiErrorKind.unauthorized => l10n.xFeedErrorUnauthorized,
        XApiErrorKind.rateLimited => l10n.xFeedErrorRateLimited,
        XApiErrorKind.network => l10n.xFeedErrorNetwork,
        XApiErrorKind.unsupported => l10n.xFeedErrorUnsupported,
        XApiErrorKind.server => l10n.xFeedErrorServer,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.all(compact ? 12 : 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact)
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          const SizedBox(height: 12),
          Text(
            message(l10n, error),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}
