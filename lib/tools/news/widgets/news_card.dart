import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../news_article.dart';
import '../news_source.dart';
import '../news_time.dart';

class NewsCard extends StatelessWidget {
  final NewsArticle article;
  final NewsSource? source;
  final VoidCallback onTap;

  const NewsCard({
    super.key,
    required this.article,
    required this.source,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final isRead = article.isRead;
    final accent = theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 620;
        final thumbSize = wide ? 168.0 : 96.0;
        final hasImage = (article.imageUrl ?? '').isNotEmpty;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Material(
            color: theme.colorScheme.surface,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onTap,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isRead
                        ? theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.45,
                          )
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Opacity(
                  opacity: isRead ? 0.64 : 1,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasImage)
                          _NewsThumbnail(
                            url: article.imageUrl!,
                            size: thumbSize,
                            wide: wide,
                          ),
                        if (hasImage) SizedBox(width: wide ? 16 : 12),
                        Expanded(
                          child: SizedBox(
                            height: hasImage ? thumbSize : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        source?.title ?? l10n.newsUnknownSource,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: accent,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      newsRelativeTimeFor(
                                        l10n,
                                        locale,
                                        article.publishedAt,
                                      ),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: theme.hintColor),
                                    ),
                                    if (!isRead) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  article.title,
                                  maxLines: wide ? 3 : 3,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      (wide
                                              ? theme.textTheme.titleMedium
                                              : theme.textTheme.titleSmall)
                                          ?.copyWith(
                                            fontWeight: isRead
                                                ? FontWeight.w500
                                                : FontWeight.w700,
                                            height: 1.25,
                                          ),
                                ),
                                if (article.summary.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    article.summary,
                                    maxLines: wide ? 3 : 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NewsThumbnail extends StatelessWidget {
  final String url;
  final double size;
  final bool wide;

  const _NewsThumbnail({
    required this.url,
    required this.size,
    required this.wide,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: theme.colorScheme.surfaceContainerHighest,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          cacheWidth: (size * (wide ? 2 : 3)).round(),
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => Icon(
            Icons.image_not_supported_outlined,
            color: theme.hintColor,
            size: size * 0.3,
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: size * 0.28,
                height: size * 0.28,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      ),
    );
  }
}
