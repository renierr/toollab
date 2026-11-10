import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/x_post.dart';
import '../x_format.dart';

/// Name, verified mark, handle and age on one line that shrinks the name first.
class XPostHeader extends StatelessWidget {
  final XPost post;
  final bool fullTime;

  const XPostHeader({super.key, required this.post, this.fullTime = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final time = fullTime
        ? XFormat.fullTime(post.createdAt, locale)
        : XFormat.relativeTime(post.createdAt, l10n, locale);

    return Row(
      children: [
        Flexible(
          child: Text(
            post.author.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (post.author.verified)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              Icons.verified,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '@${post.author.screenName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
        ),
        if (time.isNotEmpty) Text(' · $time', style: muted),
      ],
    );
  }
}
