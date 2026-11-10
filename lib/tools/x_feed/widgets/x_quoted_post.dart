import 'package:flutter/material.dart';

import '../models/x_post.dart';
import 'x_avatar.dart';
import 'x_media_grid.dart';
import 'x_post_header.dart';

class XQuotedPost extends StatelessWidget {
  final XPost post;
  final VoidCallback onTap;
  final ValueChanged<int> onOpenMedia;

  const XQuotedPost({
    super.key,
    required this.post,
    required this.onTap,
    required this.onOpenMedia,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  XAvatar(url: post.author.avatarUrl, size: 20),
                  const SizedBox(width: 6),
                  Expanded(child: XPostHeader(post: post)),
                ],
              ),
              if (post.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    post.text,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              if (post.media.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: XMediaGrid(
                    media: post.media,
                    onOpen: onOpenMedia,
                    maxHeight: 240,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
