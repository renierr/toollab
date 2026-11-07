import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

class NewsEmptyView extends StatelessWidget {
  final bool hasSources;
  final bool hideRead;
  final VoidCallback onAddSources;
  final VoidCallback onRefresh;
  final VoidCallback onShowAll;

  const NewsEmptyView({
    super.key,
    required this.hasSources,
    required this.hideRead,
    required this.onAddSources,
    required this.onRefresh,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final (icon, title, body) = !hasSources
        ? (
            Icons.rss_feed,
            l10n.newsEmptyNoSourcesTitle,
            l10n.newsEmptyNoSourcesBody,
          )
        : hideRead
        ? (
            Icons.check_circle_outline,
            l10n.newsEmptyNoUnreadTitle,
            l10n.newsEmptyNoUnreadBody,
          )
        : (
            Icons.article_outlined,
            l10n.newsEmptyNoArticlesTitle,
            l10n.newsEmptyNoArticlesBody,
          );

    final actionLabel = !hasSources
        ? l10n.newsAddSources
        : (hideRead ? l10n.newsShowAll : l10n.newsRefresh);
    final action = !hasSources
        ? onAddSources
        : (hideRead ? onShowAll : onRefresh);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 420),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: AppTheme.accentAmber),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: action,
                icon: Icon(
                  !hasSources
                      ? Icons.add
                      : (hideRead ? Icons.visibility_outlined : Icons.refresh),
                ),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
