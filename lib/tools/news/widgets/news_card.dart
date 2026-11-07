import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';

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
    final isRead = article.isRead;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.isCompact;
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
                    child: compact && hasImage
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _NewsThumbnail(
                                url: article.imageUrl!,
                                width: double.infinity,
                                height: 140,
                                cacheWidth:
                                    (constraints.maxWidth *
                                            MediaQuery.devicePixelRatioOf(
                                              context,
                                            ))
                                        .round()
                                        .clamp(1, 1200),
                              ),
                              const SizedBox(height: 10),
                              _NewsCardContent(
                                article: article,
                                source: source,
                                compact: compact,
                              ),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasImage) ...[
                                _NewsThumbnail(
                                  url: article.imageUrl!,
                                  width: 168,
                                  height: 168,
                                  cacheWidth: 336,
                                ),
                                const SizedBox(width: 16),
                              ],
                              Expanded(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: hasImage ? 168 : 0,
                                  ),
                                  child: _NewsCardContent(
                                    article: article,
                                    source: source,
                                    compact: compact,
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

class _NewsCardContent extends StatelessWidget {
  final NewsArticle article;
  final NewsSource? source;
  final bool compact;

  const _NewsCardContent({
    required this.article,
    required this.source,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final accent = theme.colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              source?.title ?? l10n.newsUnknownSource,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              newsRelativeTimeFor(l10n, locale, article.publishedAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            if (!article.isRead)
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          article.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style:
              (compact
                      ? theme.textTheme.titleSmall
                      : theme.textTheme.titleMedium)
                  ?.copyWith(
                    fontWeight: article.isRead
                        ? FontWeight.w500
                        : FontWeight.w700,
                    height: 1.25,
                  ),
        ),
        if (article.summary.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            article.summary,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _NewsThumbnail extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final int cacheWidth;

  const _NewsThumbnail({
    required this.url,
    required this.width,
    required this.height,
    required this.cacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        height: height,
        color: theme.colorScheme.surfaceContainerHighest,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          cacheWidth: cacheWidth,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => Icon(
            Icons.image_not_supported_outlined,
            color: theme.hintColor,
            size: height * 0.3,
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: height * 0.28,
                height: height * 0.28,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      ),
    );
  }
}
