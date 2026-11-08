import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/copyable_image.dart';
import 'package:tool_lab/widgets/info_card.dart';
import 'package:tool_lab/widgets/markdown_view.dart';
import 'package:tool_lab/widgets/readable_width.dart';
import 'package:url_launcher/url_launcher.dart';

import '../news_article.dart';
import '../news_article_service.dart';
import '../news_source.dart';
import '../news_state.dart';
import '../news_time.dart';
import 'news_video_actions.dart';

class NewsReaderPage extends StatefulWidget {
  final NewsArticle article;
  final NewsSource? source;

  const NewsReaderPage({super.key, required this.article, this.source});

  @override
  State<NewsReaderPage> createState() => _NewsReaderPageState();
}

class _NewsReaderPageState extends State<NewsReaderPage> with DisposeCleanup {
  Future<ExtractedArticle>? _body;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final state = context.read<NewsState>();
    _body = state.loadArticleBody(widget.article);
  }

  Future<void> _openOriginal() async {
    final uri = Uri.tryParse(widget.article.link);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _shareLink() async {
    try {
      await SharePlus.instance.share(ShareParams(text: widget.article.link));
    } catch (e) {
      errorLog('[NewsReader] Failed to share link: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).newsShareFailed)),
      );
    }
  }

  Future<void> _copyLink() async {
    final l10n = AppLocalizations.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: widget.article.link));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.newsLinkCopied)));
    } catch (e) {
      errorLog('[NewsReader] Failed to copy link: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.newsCopyFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final fontPercent = context.select<NewsState, int>(
      (state) => state.readerFontPercent,
    );
    final readerScale = fontPercent / 100;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.source?.title ?? l10n.newsUnknownSource,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: fontPercent <= NewsState.minReaderFontPercent
                ? null
                : () => context.read<NewsState>().setReaderFontPercent(
                    fontPercent - NewsState.readerFontStep,
                  ),
            icon: const Icon(Icons.text_decrease),
            tooltip: l10n.newsReaderFontSmaller,
          ),
          IconButton(
            onPressed: fontPercent >= NewsState.maxReaderFontPercent
                ? null
                : () => context.read<NewsState>().setReaderFontPercent(
                    fontPercent + NewsState.readerFontStep,
                  ),
            icon: const Icon(Icons.text_increase),
            tooltip: l10n.newsReaderFontLarger,
          ),
          IconButton(
            onPressed: _openOriginal,
            icon: const Icon(Icons.open_in_browser),
            tooltip: l10n.newsOpenInBrowser,
          ),
        ],
      ),
      body: ReadableWidth(
        maxWidth: 760,
        child: FutureBuilder<ExtractedArticle>(
          future: _body,
          builder: (context, snapshot) {
            final extracted = snapshot.data;
            final loading = snapshot.connectionState != ConnectionState.done;
            final failed = snapshot.hasError && !loading;

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
              children: [
                _ReaderHeader(
                  article: widget.article,
                  source: widget.source,
                  heroImage: widget.article.imageUrl ?? extracted?.imageUrl,
                  fontScale: readerScale,
                  relativeTime: newsRelativeTimeFor(
                    l10n,
                    locale,
                    widget.article.publishedAt,
                  ),
                ),
                const SizedBox(height: 20),
                if (loading) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 18),
                  Text(
                    l10n.newsArticleLoading,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ] else if (failed)
                  _ReaderFallback(
                    article: widget.article,
                    fontScale: readerScale,
                    onOpen: _openOriginal,
                  )
                else
                  MarkdownView(
                    data: extracted?.markdown ?? '',
                    accentColor: AppTheme.accentAmber,
                    copyImages: true,
                    scale:
                        readerScale *
                        MediaQuery.textScalerOf(context).scale(16) /
                        16,
                  ),
                if (!loading && (extracted?.videoUrls.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 16),
                  NewsVideoActions(videoUrls: extracted!.videoUrls),
                ],
                const SizedBox(height: 28),
                Divider(color: theme.colorScheme.outlineVariant),
                const SizedBox(height: 16),
                Text(
                  l10n.newsSourceLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  widget.article.link,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _openOriginal,
                      icon: const Icon(Icons.open_in_browser, size: 18),
                      label: Text(
                        l10n.newsReadOnSource(
                          widget.source?.title ?? l10n.newsUnknownSource,
                        ),
                      ),
                    ),
                    if (defaultTargetPlatform == TargetPlatform.android)
                      FilledButton.tonalIcon(
                        onPressed: widget.article.link.trim().isEmpty
                            ? null
                            : _shareLink,
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: Text(l10n.newsShareLink),
                      ),
                    FilledButton.tonalIcon(
                      onPressed: widget.article.link.trim().isEmpty
                          ? null
                          : _copyLink,
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text(l10n.newsCopyLink),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReaderHeader extends StatelessWidget {
  final NewsArticle article;
  final NewsSource? source;
  final String? heroImage;
  final String relativeTime;
  final double fontScale;

  const _ReaderHeader({
    required this.article,
    required this.source,
    required this.heroImage,
    required this.relativeTime,
    required this.fontScale,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final image = heroImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  source?.title ?? l10n.newsUnknownSource,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.accentAmberLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                relativeTime,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SelectableText(
          article.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize:
                (theme.textTheme.headlineSmall?.fontSize ?? 24) * fontScale,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        if ((article.author ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            article.author!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (image != null && image.isNotEmpty) ...[
          const SizedBox(height: 16),
          CopyableImage(
            image: NetworkImage(image),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  image,
                  fit: BoxFit.cover,
                  cacheWidth: 1200,
                  errorBuilder: (_, _, _) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: theme.hintColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReaderFallback extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback onOpen;
  final double fontScale;

  const _ReaderFallback({
    required this.article,
    required this.onOpen,
    required this.fontScale,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoCard(
          icon: Icons.info_outline,
          title: l10n.newsArticleFailedTitle,
          child: Text(
            l10n.newsArticleFailedBody,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        if (article.summary.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.newsReaderSummaryLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            article.summary,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: (theme.textTheme.bodyLarge?.fontSize ?? 16) * fontScale,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_browser, size: 18),
            label: Text(l10n.newsOpenOriginal),
          ),
        ),
      ],
    );
  }
}
