import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../models/x_post.dart';
import '../x_feed_state.dart';
import '../x_format.dart';
import 'x_post_menu.dart';

class XPostActions extends StatelessWidget {
  final XPost post;
  final VoidCallback onReply;

  const XPostActions({super.key, required this.post, required this.onReply});

  Future<void> _run(
    BuildContext context,
    Future<bool> Function() action,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (!await action()) {
      messenger?.showSnackBar(SnackBar(content: Text(l10n.xFeedActionFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final engagement = context.select<XFeedState, XEngagement>(
      (s) => s.engagementOf(post),
    );
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cramped = constraints.maxWidth < 320;
        String count(int value) => cramped ? '' : XFormat.count(value, locale);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ActionButton(
              icon: Icons.mode_comment_outlined,
              label: count(post.replies),
              tooltip: l10n.xFeedReplies,
              color: muted,
              onPressed: onReply,
            ),
            _ActionButton(
              icon: Icons.repeat,
              label: count(engagement.reposts),
              tooltip: engagement.reposted
                  ? l10n.xFeedUndoRepost
                  : l10n.xFeedRepost,
              color: engagement.reposted ? AppTheme.statusGreen : muted,
              onPressed: () => _run(
                context,
                () => context.read<XFeedState>().toggleRepost(post),
              ),
            ),
            _ActionButton(
              icon: engagement.liked ? Icons.favorite : Icons.favorite_border,
              label: count(engagement.likes),
              tooltip: engagement.liked ? l10n.xFeedUnlike : l10n.xFeedLike,
              color: engagement.liked ? AppTheme.accentRed : muted,
              onPressed: () => _run(
                context,
                () => context.read<XFeedState>().toggleLike(post),
              ),
            ),
            _ActionButton(
              icon: engagement.bookmarked
                  ? Icons.bookmark
                  : Icons.bookmark_border,
              tooltip: engagement.bookmarked
                  ? l10n.xFeedRemoveBookmark
                  : l10n.xFeedBookmark,
              color: engagement.bookmarked ? AppTheme.accentBlue : muted,
              onPressed: () => _run(
                context,
                () => context.read<XFeedState>().toggleBookmark(post),
              ),
            ),
            _ActionButton(
              icon: Icons.share_outlined,
              tooltip: l10n.commonShare,
              color: muted,
              onPressed: () => unawaited(XPostMenu.show(context, post)),
            ),
          ],
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
    this.label = '',
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}
