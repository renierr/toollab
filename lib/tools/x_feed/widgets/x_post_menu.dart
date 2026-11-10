import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/x_media.dart';
import '../models/x_post.dart';
import '../x_feed_state.dart';
import '../x_media_actions.dart';
import '../x_navigation.dart';

/// Every action on a post in one list: the share menu on touch, and the
/// long-press menu a TV remote reaches the post's controls through.
class XPostMenu extends StatelessWidget {
  final XPost post;

  /// The page the menu opened from; actions outlive the closed sheet there.
  final BuildContext hostContext;

  const XPostMenu({super.key, required this.post, required this.hostContext});

  static Future<void> show(BuildContext context, XPost post) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => XPostMenu(post: post, hostContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<XFeedState>();
    final engagement = state.engagementOf(post);
    final media = post.allMedia;

    void run(Future<void> Function(BuildContext context) action) {
      Navigator.of(context).pop();
      if (hostContext.mounted) unawaited(action(hostContext));
    }

    String mediaLabel(String base, int index) =>
        media.length > 1 ? '$base (${index + 1})' : base;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          for (var i = 0; i < media.length; i++)
            ListTile(
              autofocus: i == 0,
              leading: Icon(
                media[i].isPlayable ? Icons.play_circle_outline : Icons.image,
              ),
              title: Text(
                mediaLabel(
                  media[i].isPlayable
                      ? l10n.xFeedPlayMedia
                      : l10n.xFeedViewImage,
                  i,
                ),
              ),
              onTap: () => run((c) => XMediaActions.openMedia(c, post, i)),
            ),
          ListTile(
            autofocus: media.isEmpty,
            leading: Icon(
              engagement.liked ? Icons.favorite : Icons.favorite_border,
            ),
            title: Text(engagement.liked ? l10n.xFeedUnlike : l10n.xFeedLike),
            onTap: () => unawaited(state.toggleLike(post)),
          ),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: Text(
              engagement.reposted ? l10n.xFeedUndoRepost : l10n.xFeedRepost,
            ),
            onTap: () => unawaited(state.toggleRepost(post)),
          ),
          ListTile(
            leading: Icon(
              engagement.bookmarked ? Icons.bookmark : Icons.bookmark_border,
            ),
            title: Text(
              engagement.bookmarked
                  ? l10n.xFeedRemoveBookmark
                  : l10n.xFeedBookmark,
            ),
            onTap: () => unawaited(state.toggleBookmark(post)),
          ),
          const Divider(),
          for (var i = 0; i < media.length; i++) ...[
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(mediaLabel(l10n.xFeedShareMedia, i)),
              onTap: () =>
                  run((c) => XMediaActions.shareMedia(c, post, media[i])),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(mediaLabel(l10n.xFeedSaveMedia, i)),
              onTap: () =>
                  run((c) => XMediaActions.saveMedia(c, post, media[i])),
            ),
            if (media[i].type == XMediaType.photo)
              ListTile(
                leading: const Icon(Icons.copy_all_outlined),
                title: Text(mediaLabel(l10n.xFeedCopyImage, i)),
                onTap: () =>
                    run((c) => XMediaActions.copyImage(c, post, media[i])),
              ),
          ],
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: Text(l10n.xFeedShareLink),
            onTap: () => run((c) => XMediaActions.sharePostLink(c, post)),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(l10n.xFeedCopyLink),
            onTap: () => run(
              (c) => XMediaActions.copyText(c, post.url, l10n.xFeedLinkCopied),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.open_in_browser),
            title: Text(l10n.xFeedOpenInBrowser),
            onTap: () =>
                run((c) => XMediaActions.openUrl(c, Uri.parse(post.url))),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.xFeedViewProfile(post.author.screenName)),
            onTap: () =>
                run((c) => XNavigation.openUser(c, post.author.screenName)),
          ),
        ],
      ),
    );
  }
}
