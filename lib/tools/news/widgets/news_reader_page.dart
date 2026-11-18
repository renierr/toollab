import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/scroll_nudger.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/text_ai/text_ai_action.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/back_key_scope.dart';
import 'package:tool_lab/widgets/copyable_image.dart';
import 'package:tool_lab/widgets/image_preview_dialog.dart';
import 'package:tool_lab/widgets/info_card.dart';
import 'package:tool_lab/widgets/markdown_view.dart';
import 'package:tool_lab/widgets/readable_width.dart';
import 'package:tool_lab/widgets/text_ai_sheet.dart';
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
  final ScrollController _scroll = ScrollController();
  final ScrollNudger _nudger = ScrollNudger();

  @override
  void initState() {
    super.initState();
    onDispose(_scroll.dispose);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final nudge = ScrollNudger.directionOf(event);
    if (nudge == null) return KeyEventResult.ignored;
    _nudger.nudge(_scroll, nudge);
    return KeyEventResult.handled;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final state = context.read<NewsState>();
    _body = state.loadArticleBody(widget.article);
  }

  bool get _hasLink => widget.article.link.trim().isNotEmpty;

  static final _image = RegExp(r'!\[[^\]]*\]\([^)]*\)');
  static final _link = RegExp(r'\[([^\]]*)\]\([^)]*\)');
  static final _webLink = RegExp(r'(?<!!)\[([^\]]*)\]\((https?://[^)\s]+)');

  /// Inline Markdown links cannot take remote focus; TV lists them instead.
  static List<({String label, String url})> _webLinks(String markdown) {
    final seen = <String>{};
    return [
      for (final match in _webLink.allMatches(markdown))
        if (seen.add(match[2]!)) (label: match[1]!.trim(), url: match[2]!),
    ];
  }

  // Aggregators such as Hacker News link to other sites; name the target.
  static String? _linkHost(String link, String? siteUrl) {
    String host(String url) => (Uri.tryParse(url.trim())?.host ?? '')
        .replaceFirst(RegExp(r'^www\.'), '');
    final target = host(link);
    if (target.isEmpty || target == host(siteUrl ?? '')) return null;
    return target;
  }

  Future<void> _openTextAi() async {
    String body;
    try {
      body = (await _body)?.markdown ?? '';
    } catch (_) {
      body = '';
    }
    if (!mounted) return;
    if (body.trim().isEmpty) body = widget.article.summary;
    final text = '${widget.article.title}\n\n$body'
        .replaceAll(_image, '')
        .replaceAllMapped(_link, (m) => m[1]!)
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    await TextAiSheet.show(
      context,
      text: text,
      actions: TextAiAction.reading,
      canApply: false,
    );
  }

  Future<void> _openOriginal() => _openUrl(widget.article.link.trim());

  Future<void> _openUrl(String url) async {
    final l10n = AppLocalizations.of(context);
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('No handler for the link');
    } catch (e) {
      errorLog('[NewsReader] Failed to open original: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.newsOpenFailed)));
    }
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
    final tvMode = context.select<AppState?, bool>((s) => s?.tvMode ?? false);

    // Outside the back-key scope, which holds the focus until a control takes it.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: BackKeyScope(
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.source?.title ?? l10n.newsUnknownSource,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                onPressed: _openTextAi,
                icon: const Icon(Icons.auto_awesome_outlined),
                tooltip: l10n.textAiOpen,
              ),
              IconButton(
                onPressed: fontPercent <= NewsState.minFontPercent
                    ? null
                    : () => context.read<NewsState>().setReaderFontPercent(
                        fontPercent - NewsState.fontStep,
                      ),
                icon: const Icon(Icons.text_decrease),
                tooltip: l10n.newsReaderFontSmaller,
              ),
              IconButton(
                onPressed: fontPercent >= NewsState.maxFontPercent
                    ? null
                    : () => context.read<NewsState>().setReaderFontPercent(
                        fontPercent + NewsState.fontStep,
                      ),
                icon: const Icon(Icons.text_increase),
                tooltip: l10n.newsReaderFontLarger,
              ),
              IconButton(
                onPressed: _hasLink ? _openOriginal : null,
                icon: const Icon(Icons.open_in_browser),
                tooltip: l10n.newsOpenInBrowser,
              ),
            ],
          ),
          body: FutureBuilder<ExtractedArticle>(
            future: _body,
            builder: (context, snapshot) {
              final extracted = snapshot.data;
              final loading = snapshot.connectionState != ConnectionState.done;
              final failed = snapshot.hasError && !loading;

              return ReadableScrollPadding(
                maxWidth: 760,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                builder: (context, padding) => ListView(
                  controller: _scroll,
                  padding: padding,
                  children: [
                    _ReaderHeader(
                      article: widget.article,
                      source: widget.source,
                      heroImage: widget.article.imageUrl ?? extracted?.imageUrl,
                      fontScale: readerScale,
                      meta: [
                        ?_linkHost(widget.article.link, widget.source?.siteUrl),
                        newsRelativeTimeFor(
                          l10n,
                          locale,
                          widget.article.publishedAt,
                        ),
                        if (newsReadingMinutes(extracted?.markdown ?? '')
                            case final minutes?)
                          l10n.newsReadingMinutes(minutes),
                      ].where((part) => part.isNotEmpty).join(' · '),
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
                        onOpen: _hasLink ? _openOriginal : null,
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
                    if (!loading &&
                        (extracted?.videoUrls.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 16),
                      NewsVideoActions(videoUrls: extracted!.videoUrls),
                    ],
                    if (tvMode && !loading && !failed)
                      _ReaderLinks(
                        links: _webLinks(extracted?.markdown ?? ''),
                        onOpen: _openUrl,
                      ),
                    const SizedBox(height: 28),
                    _ReaderLinkFooter(
                      link: widget.article.link,
                      sourceTitle:
                          widget.source?.title ?? l10n.newsUnknownSource,
                      onOpen: _hasLink ? _openOriginal : null,
                      onShare: _hasLink ? _shareLink : null,
                      onCopy: _hasLink ? _copyLink : null,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReaderHeader extends StatelessWidget {
  final NewsArticle article;
  final NewsSource? source;
  final String? heroImage;
  final String meta;
  final double fontScale;

  const _ReaderHeader({
    required this.article,
    required this.source,
    required this.heroImage,
    required this.meta,
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
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
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
            Text(
              meta,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.hintColor,
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
            focusable: true,
            onTap: () => ImagePreviewDialog.show(
              context: context,
              image: NetworkImage(image),
            ),
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

class _ReaderLinks extends StatelessWidget {
  final List<({String label, String url})> links;
  final ValueChanged<String> onOpen;

  const _ReaderLinks({required this.links, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          l10n.newsArticleLinks,
          style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor),
        ),
        for (final link in links)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link),
            title: Text(
              link.label.isEmpty ? link.url : link.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: link.label.isEmpty
                ? null
                : Text(link.url, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => onOpen(link.url),
          ),
      ],
    );
  }
}

class _ReaderLinkFooter extends StatelessWidget {
  final String link;
  final String sourceTitle;
  final VoidCallback? onOpen;
  final VoidCallback? onShare;
  final VoidCallback? onCopy;

  const _ReaderLinkFooter({
    required this.link,
    required this.sourceTitle,
    required this.onOpen,
    required this.onShare,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: theme.colorScheme.outlineVariant),
        const SizedBox(height: 16),
        Text(
          l10n.newsSourceLabel,
          style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 4),
        SelectableText(link, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_browser, size: 18),
              label: Text(l10n.newsReadOnSource(sourceTitle)),
            ),
            if (defaultTargetPlatform == TargetPlatform.android)
              FilledButton.tonalIcon(
                onPressed: onShare,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: Text(l10n.newsShareLink),
              ),
            FilledButton.tonalIcon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy, size: 18),
              label: Text(l10n.newsCopyLink),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReaderFallback extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback? onOpen;
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
