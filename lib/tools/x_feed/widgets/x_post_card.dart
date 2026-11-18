import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/focus_outline.dart';
import 'package:tool_lab/widgets/text_scale_multiplier.dart';

import '../models/x_post.dart';
import '../x_feed_state.dart';
import '../x_keys.dart';
import '../x_media_actions.dart';
import '../x_navigation.dart';
import '../x_translation_actions.dart';
import 'x_avatar.dart';
import 'x_broadcast_tile.dart';
import 'x_link_card.dart';
import 'x_media_grid.dart';
import 'x_post_actions.dart';
import 'x_post_header.dart';
import 'x_post_menu.dart';
import 'x_quoted_post.dart';
import 'x_rich_text.dart';
import 'x_search_page.dart';
import 'x_translation_bar.dart';

/// One post in a list and one keyboard / remote focus stop: OK opens the
/// thread, holding OK opens [XPostMenu], Space opens the media. Down moves into
/// the post's media, where each tile is its own focus stop and OK plays it.
class XPostCard extends StatefulWidget {
  final XPost post;

  /// The thread's own post: larger text, full timestamp, no tap-through.
  final bool focal;
  final bool autofocus;

  /// Draw the thread line to the parent above / the reply below.
  final bool threadAbove;
  final bool threadBelow;

  const XPostCard({
    super.key,
    required this.post,
    this.focal = false,
    this.autofocus = false,
    this.threadAbove = false,
    this.threadBelow = false,
  });

  @override
  State<XPostCard> createState() => _XPostCardState();
}

class _XPostCardState extends State<XPostCard> with DisposeCleanup {
  final FocusNode _cardNode = FocusNode(debugLabel: 'XPostCard');
  late List<FocusNode> _mediaNodes = _createMediaNodes();

  /// The post's own tiles come first, then the quoted post's.
  List<FocusNode> _createMediaNodes() => [
    for (var i = 0; i < _ownMediaCount + _quotedMediaCount; i++)
      FocusNode(debugLabel: 'XPostMedia$i'),
  ];

  int get _ownMediaCount => widget.post.media.length.clamp(0, 4);
  int get _quotedMediaCount =>
      (widget.post.quoted?.media.length ?? 0).clamp(0, 4);

  @override
  void initState() {
    super.initState();
    onDispose(() {
      _cardNode.dispose();
      for (final node in _mediaNodes) {
        node.dispose();
      }
    });
    _requestTranslation();
  }

  /// Cards are built as they near the viewport, so automatic translations
  /// are fetched for what is about to be read, not the whole feed.
  void _requestTranslation() {
    if (!widget.post.canTranslate) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<XFeedState>().translator.request(widget.post);
    });
  }

  @override
  void didUpdateWidget(covariant XPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      _requestTranslation();
      for (final node in _mediaNodes) {
        node.dispose();
      }
      _mediaNodes = _createMediaNodes();
    }
  }

  void _open() {
    if (!widget.focal) unawaited(XNavigation.openPost(context, widget.post));
  }

  void _menu() => unawaited(XPostMenu.show(context, widget.post));

  void _focusMedia(int index) {
    final target = _mediaNodes[index];
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
    if (_mediaNodes.isNotEmpty && !HardwareKeyboard.instance.isShiftPressed) {
      if (key == LogicalKeyboardKey.arrowDown && _cardNode.hasPrimaryFocus) {
        _focusMedia(0);
        return KeyEventResult.handled;
      }
      final focused = _mediaNodes.indexWhere((n) => n.hasPrimaryFocus);
      // Left / right walk the tiles in order; past either end they step posts.
      if (focused >= 0 &&
          key == LogicalKeyboardKey.arrowRight &&
          focused + 1 < _mediaNodes.length) {
        _focusMedia(focused + 1);
        return KeyEventResult.handled;
      }
      if (focused > 0 && key == LogicalKeyboardKey.arrowLeft) {
        _focusMedia(focused - 1);
        return KeyEventResult.handled;
      }
      if (focused >= 0 && key == LogicalKeyboardKey.arrowUp) {
        final own = _ownMediaCount;
        final inQuoted = focused >= own;
        // The top row is tile 0 and tile 1 in every grid layout.
        if ((inQuoted ? focused - own : focused) < 2) {
          if (inQuoted && own > 0) {
            _focusMedia(0);
          } else {
            _cardNode.requestFocus();
          }
          return KeyEventResult.handled;
        }
      }
    }
    final playsBroadcast =
        widget.post.broadcast != null && widget.post.media.isEmpty;
    if (playsBroadcast &&
        _cardNode.hasPrimaryFocus &&
        (key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.mediaPlayPause ||
            key == LogicalKeyboardKey.mediaPlay)) {
      unawaited(XMediaActions.openBroadcast(context, widget.post));
      return KeyEventResult.handled;
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
    if (key == LogicalKeyboardKey.keyT && widget.post.canTranslate) {
      unawaited(XTranslationActions.toggle(context, widget.post));
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
    final broadcast = post.media.isEmpty ? post.broadcast : null;
    final quoted = post.quoted;
    final translation = post.canTranslate
        ? context.select<XFeedState, XTranslation?>(
            (s) => s.translator.shownOf(post),
          )
        : null;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        XPostHeader(post: post, fullTime: widget.focal),
        if (replyTo != null && !widget.focal && !widget.threadAbove)
          Text(l10n.xFeedReplyingTo(replyTo), style: muted),
        if (post.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: XRichText(
              text: translation?.text ?? post.text,
              links: translation?.links ?? post.links,
              style: widget.focal
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyLarge,
              onLink: (url) => XMediaActions.openUrl(context, Uri.parse(url)),
              onMention: (name) => XNavigation.openUser(context, name),
              onHashtag: (tag) => XSearchPage.open(context, tag),
            ),
          ),
        if (post.canTranslate)
          ExcludeFocus(
            child: XTranslationBar(post: post, translation: translation),
          ),
        if (post.media.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: XMediaGrid(
              media: post.media,
              maxHeight: widget.focal ? 640 : 420,
              focusNodes: _mediaNodes.sublist(0, _ownMediaCount),
              onOpen: (i) => XMediaActions.openMedia(context, post, i),
            ),
          ),
        if (quoted != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: XQuotedPost(
              post: quoted,
              mediaFocusNodes: _mediaNodes.sublist(_ownMediaCount),
              onTap: () => XNavigation.openPost(context, quoted),
              onOpenMedia: (i) =>
                  XMediaActions.openMedia(context, post, post.media.length + i),
            ),
          ),
        if (broadcast != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: ExcludeFocus(
              child: XBroadcastTile(
                broadcast: broadcast,
                onTap: () => XMediaActions.openBroadcast(context, post),
              ),
            ),
          ),
        if (card != null &&
            broadcast == null &&
            post.media.isEmpty &&
            quoted == null)
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
            child: XPostActions(post: post, onReply: _open),
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
                  _ThreadLines(
                    above: widget.threadAbove,
                    below: widget.threadBelow,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () => XNavigation.openUser(
                                context,
                                post.author.screenName,
                              ),
                              child: XAvatar(url: post.author.avatarUrl),
                            ),
                            _ReadMark(post: post),
                          ],
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

    final textScale = context.select<XFeedState, double>((s) => s.textScale);
    return TextScaleMultiplier(scale: textScale, child: content);
  }
}

class _ReadMark extends StatelessWidget {
  final XPost post;

  const _ReadMark({required this.post});

  @override
  Widget build(BuildContext context) {
    final state = context.read<XFeedState>();
    return ListenableBuilder(
      listenable: state.readMarks,
      builder: (context, _) {
        final mark = state.readMarkOf(post);
        if (mark == XReadMark.none) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context);
        final scheme = Theme.of(context).colorScheme;
        final sent = mark == XReadMark.sent;
        final color = sent ? scheme.primary : scheme.onSurfaceVariant;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Tooltip(
            message: sent ? l10n.xFeedSeenSent : l10n.xFeedSeenPending,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sent ? color : color.withValues(alpha: 0.15),
                border: Border.all(color: color, width: 1.5),
              ),
              child: Icon(
                sent ? Icons.done_all : Icons.done,
                size: 20,
                color: sent ? scheme.onPrimary : color,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The vertical line joining this post's avatar to its thread neighbours. It
/// reaches into the card's 10 px top and 4 px bottom padding.
class _ThreadLines extends StatelessWidget {
  static const double _avatar = 44;
  static const double _width = 2;
  static const double _left = (_avatar - _width) / 2;

  final bool above;
  final bool below;
  final Widget child;

  const _ThreadLines({
    required this.above,
    required this.below,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!above && !below) return child;
    final line = ColoredBox(
      color: Theme.of(context).colorScheme.outlineVariant,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (above)
          Positioned(
            left: _left,
            width: _width,
            top: -10,
            height: 8,
            child: line,
          ),
        if (below)
          Positioned(
            left: _left,
            width: _width,
            top: _avatar + 2,
            bottom: -4,
            child: line,
          ),
        child,
      ],
    );
  }
}
