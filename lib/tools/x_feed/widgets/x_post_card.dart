import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/focus_outline.dart';

import '../models/x_post.dart';
import '../x_media_actions.dart';
import '../x_navigation.dart';
import 'x_avatar.dart';
import 'x_link_card.dart';
import 'x_media_grid.dart';
import 'x_post_actions.dart';
import 'x_post_header.dart';
import 'x_post_menu.dart';
import 'x_quoted_post.dart';
import 'x_rich_text.dart';
import 'x_search_page.dart';

/// One post in a list. On a TV the whole card is a single focus stop: OK opens
/// the thread, holding OK opens [XPostMenu], Play starts the first video.
class XPostCard extends StatelessWidget {
  final XPost post;
  final bool tvMode;

  /// The thread's own post: larger text, full timestamp, no tap-through.
  final bool focal;
  final bool autofocus;

  const XPostCard({
    super.key,
    required this.post,
    required this.tvMode,
    this.focal = false,
    this.autofocus = false,
  });

  void _open(BuildContext context) {
    if (!focal) unawaited(XNavigation.openPost(context, post));
  }

  void _menu(BuildContext context) => unawaited(XPostMenu.show(context, post));

  KeyEventResult _onKey(BuildContext context, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.mediaPlay) {
      final index = post.allMedia.indexWhere((m) => m.isPlayable);
      if (index < 0) return KeyEventResult.ignored;
      unawaited(XMediaActions.openMedia(context, post, index));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.contextMenu) {
      _menu(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final reposter = post.repostedBy;
    final replyTo = post.replyToScreenName;
    final card = post.card;
    final quoted = post.quoted;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        XPostHeader(post: post, fullTime: focal),
        if (replyTo != null && !focal)
          Text(l10n.xFeedReplyingTo(replyTo), style: muted),
        if (post.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: XRichText(
              text: post.text,
              links: post.links,
              style: focal
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyLarge,
              onLink: (url) => XMediaActions.openUrl(context, Uri.parse(url)),
              onMention: (name) => XNavigation.openUser(context, name),
              onHashtag: (tag) => XSearchPage.open(context, tag),
            ),
          ),
        if (post.media.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: XMediaGrid(
              media: post.media,
              maxHeight: focal ? 640 : 420,
              onOpen: (i) => XMediaActions.openMedia(context, post, i),
            ),
          ),
        if (quoted != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: XQuotedPost(
              post: quoted,
              onTap: () => XNavigation.openPost(context, quoted),
              onOpenMedia: (i) =>
                  XMediaActions.openMedia(context, post, post.media.length + i),
            ),
          ),
        if (card != null && post.media.isEmpty && quoted == null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: XLinkCardView(
              card: card,
              onTap: () => XMediaActions.openUrl(context, Uri.parse(card.url)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: XPostActions(post: post, onReply: () => _open(context)),
        ),
      ],
    );

    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) => _onKey(context, event),
      child: FocusOutline(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(context),
        onLongPress: () => _menu(context),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            autofocus: autofocus,
            borderRadius: BorderRadius.circular(12),
            onTap: focal ? null : () => _open(context),
            onLongPress: () => _menu(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (reposter != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 28, bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.repeat, size: 16, color: muted?.color),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l10n.xFeedReposted(reposter.name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ExcludeFocus(
                    excluding: tvMode,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => XNavigation.openUser(
                            context,
                            post.author.screenName,
                          ),
                          child: XAvatar(url: post.author.avatarUrl),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: body),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
