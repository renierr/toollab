import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/x_user.dart';
import '../x_format.dart';
import 'x_avatar.dart';

class XUserHeader extends StatelessWidget {
  final XUser user;
  final bool mediaOnly;
  final ValueChanged<bool> onMediaOnlyChanged;

  const XUserHeader({
    super.key,
    required this.user,
    required this.mediaOnly,
    required this.onMediaOnlyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final banner = user.bannerUrl;
    final bio = user.bio;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (banner != null)
          AspectRatio(
            aspectRatio: 3,
            child: Image.network(
              '$banner/1500x500',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  XAvatar(url: user.largeAvatarUrl, size: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: theme.textTheme.titleLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text('@${user.screenName}', style: muted),
                      ],
                    ),
                  ),
                ],
              ),
              if (bio != null && bio.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(bio, style: theme.textTheme.bodyMedium),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    if (user.following != null)
                      Text(
                        l10n.xFeedFollowingCount(
                          XFormat.count(user.following!, locale),
                        ),
                        style: muted,
                      ),
                    if (user.followers != null)
                      Text(
                        l10n.xFeedFollowersCount(
                          XFormat.count(user.followers!, locale),
                        ),
                        style: muted,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(l10n.xFeedPosts)),
                    ButtonSegment(value: true, label: Text(l10n.xFeedMedia)),
                  ],
                  selected: {mediaOnly},
                  onSelectionChanged: (s) => onMediaOnlyChanged(s.first),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
