import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../news_article.dart';
import '../news_source.dart';
import '../news_time.dart';
import 'news_card.dart';
import 'news_read_tracker.dart';

class NewsList extends StatelessWidget {
  final List<NewsArticle> articles;
  final NewsSource? Function(String sourceId) sourceResolver;
  final bool markReadOnScroll;
  final Widget empty;
  final Future<void> Function() onRefresh;
  final void Function(NewsArticle article) onOpen;
  final void Function(NewsArticle article) onSeen;

  const NewsList({
    super.key,
    required this.articles,
    required this.sourceResolver,
    required this.markReadOnScroll,
    required this.empty,
    required this.onRefresh,
    required this.onOpen,
    required this.onSeen,
  });

  @override
  Widget build(BuildContext context) {
    return ReadableWidth(
      maxWidth: 900,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: articles.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [empty],
              )
            : _TimelineList(
                articles: articles,
                sourceResolver: sourceResolver,
                markReadOnScroll: markReadOnScroll,
                onOpen: onOpen,
                onSeen: onSeen,
              ),
      ),
    );
  }
}

class _TimelineList extends StatelessWidget {
  final List<NewsArticle> articles;
  final NewsSource? Function(String sourceId) sourceResolver;
  final bool markReadOnScroll;
  final void Function(NewsArticle article) onOpen;
  final void Function(NewsArticle article) onSeen;

  const _TimelineList({
    required this.articles,
    required this.sourceResolver,
    required this.markReadOnScroll,
    required this.onOpen,
    required this.onSeen,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final entries = <_TimelineEntry>[];
    DateTime? previousDay;
    for (final article in articles) {
      final date = DateTime.fromMillisecondsSinceEpoch(article.publishedAt);
      final day = DateTime(date.year, date.month, date.day);
      if (previousDay == null || day != previousDay) {
        entries.add(
          _TimelineEntry.header(newsDayLabel(l10n, locale, date, now)),
        );
        previousDay = day;
      }
      entries.add(_TimelineEntry.article(article));
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 28),
      scrollCacheExtent: const ScrollCacheExtent.pixels(500),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final article = entry.article;
        if (article == null) {
          return _DateHeader(label: entry.header ?? '');
        }
        return NewsReadTracker(
          key: ValueKey(article.guidKey),
          article: article,
          enabled: markReadOnScroll,
          onSeen: () => onSeen(article),
          child: NewsCard(
            article: article,
            source: sourceResolver(article.sourceShortId),
            onTap: () => onOpen(article),
          ),
        );
      },
    );
  }
}

class _TimelineEntry {
  final String? header;
  final NewsArticle? article;

  const _TimelineEntry.header(this.header) : article = null;
  const _TimelineEntry.article(this.article) : header = null;
}

class _DateHeader extends StatelessWidget {
  final String label;

  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
