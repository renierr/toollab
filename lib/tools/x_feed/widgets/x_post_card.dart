import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/focus_outline.dart';

import '../models/x_post.dart';
import '../x_feed_state.dart';
import '../x_keys.dart';
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

/// One post in a list and one keyboard / remote focus stop: OK opens the
/// thread, holding OK opens [XPostMenu], Space opens the media. Down moves into
/// the post's media, where each tile is its own focus stop and OK plays it.
class XPostCard extends StatefulWidget {
  final XPost post;

  /// The thread's own post: larger text, full timestamp, no tap-through.
  final bool focal;
  final bool autofocus;

  const XPostCard({
    super.key,
    required this.post,
    this.focal = false,
    this.autofocus = false,
  });

  @override
  State<XPostCard> createState() => _XPostCardState();
}

class _XPostCardState extends State<XPostCard> {
  final FocusNode _cardNode = FocusNode(debugLabel: 'XPostCard');
  late List<FocusNode> _mediaNodes = _createMediaNodes();

  List<FocusNode> _createMediaNodes() => [
    for (var i = 0; i < widget.post.media.length.clamp(0, 4); i++)
      FocusNode(debugLabel: 'XPostMedia$i'),
  ];

  @override
  void didUpdateWidget(covariant XPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      for (final node in _mediaNodes) {
        node.dispose();
      }
      _mediaNodes = _createMediaNodes();
    }
  }

  @override
  void dispose() {
    _cardNode.dispose();
    for (final node in _mediaNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _open() {
    if (!widget.focal) unawaited(XNavigation.openPost(context, widget.post));
  }

  void _menu() => unawaited(XPostMenu.show(context, widget.post));

  void _focusFirstMedia() {
    final target = _mediaNodes.first;
    target.requestFocus();
    final context = target.context;
    if (context == null || !context.mounted) return;
    Scrollable.ensureVisible(
      context,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (_mediaNodes.isNotEmpty) {
      if (key == LogicalKeyboardKey.arrowDown && _cardNode.hasPrimaryFocus) {
        _focusFirstMedia();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        // The top row is tile 0 and tile 1 in every grid layout.
        for (var i = 0; i < _mediaNodes.length && i < 2; i++) {
          if (_mediaNodes[i].hasPrimaryFocus) {
            _cardNode.requestFocus();
            return KeyEventResult.handled;
          }
        }
      }
    }
    if (key == LogicalKeyboardKey.space && _cardNode.hasPrimaryFocus) {
      final media = widget.post.allMedia;
      if (media.isEmpty) return KeyEventResult.ignored;
      final playable = media.indexWhere((m) => m.isPlayable);
      unawaited(
        XMediaActions.openMedia(
          context,
          widget.post,
          playable < 0 ? 0 : playable,
        ),
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.mediaPlay) {
      final index = widget.post.allMedia.indexWhere((m) => m.isPlayable);
      if (index < 0) return KeyEventResult.ignored;
      unawaited(XMediaActions.openMedia(context, widget.post, index));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.contextMenu) {
      _menu();
      return KeyEventResult.handled;
    }
    if (!XKeys.plain) return KeyEventResult.ignored;
    final state = context.read<XFeedState>();
    if (key == LogicalKeyboardKey.keyL) {
      unawaited(_engage(() => state.toggleLike(widget.post)));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyB) {
      unawaited(_engage(() => state.toggleBookmark(widget.post)));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyU) {
      unawaited(XNavigation.openUser(context, widget.post.author.screenName));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _engage(Future<bool> Function() action) async {
    final failed = AppLocalizations.of(context).xFeedActionFailed;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (!await action()) {
      messenger?.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final post = widget.post;
    final reposter = post.repostedBy;
    final replyTo = post.replyToScreenName;
    final card = post.card;
    final quoted = post.quoted;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        XPostHeader(post: post, fullTime: widget.focal),
        if (replyTo != null && !widget.focal)
          Text(l10n.xFeedReplyingTo(replyTo), style: muted),
        if (post.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: XRichText(
              text: post.text,
              links: post.links,
              style: widget.focal
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
              maxHeight: widget.focal ? 640 : 420,
              focusNodes: _mediaNodes,
              onOpen: (i) => XMediaActions.openMedia(context, post, i),
            ),
          ),
        if (quoted != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: ExcludeFocus(
              child: XQuotedPost(
                post: quoted,
                onTap: () => XNavigation.openPost(context, quoted),
                onOpenMedia: (i) => XMediaActions.openMedia(
                  context,
                  post,
                  post.media.length + i,
                ),
              ),
            ),
          ),
        if (card != null && post.media.isEmpty && quoted == null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: ExcludeFocus(
              child: XLinkCardView(
                card: card,
                onTap: () =>
                    XMediaActions.openUrl(context, Uri.parse(card.url)),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: ExcludeFocus(
            child: XPostActions(post: post, onReply: () => _open()),
          ),
        ),
      ],
    );

    final Widget content = Focus(
      canRequestFocus: false,
      onKeyEvent: _onKey,
      child: FocusOutline(
        borderRadius: BorderRadius.circular(12),
        glow: false,
        onTap: _open,
        onLongPress: _menu,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            autofocus: widget.autofocus,
            focusNode: _cardNode,
            focusColor: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            onTap: widget.focal ? null : _open,
            onLongPress: _menu,
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
                  Row(
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
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final textScale = context.select<XFeedState, double>((s) => s.textScale);
    if (textScale == 1.0) return content;
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: TextScaler.linear(media.textScaler.scale(1) * textScale),
      ),
      child: content,
    );
  }
}
