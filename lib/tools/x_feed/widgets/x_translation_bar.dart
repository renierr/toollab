import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/x_post.dart';
import '../x_feed_state.dart';
import '../x_translation_actions.dart';

/// x.com's "Translate post" link under a post's text, and the
/// "Translated from …" line with its way back once translated.
class XTranslationBar extends StatelessWidget {
  final XPost post;
  final XTranslation? translation;

  const XTranslationBar({super.key, required this.post, this.translation});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = XTranslationActions.targetLanguage(context);
    final busy = context.select<XFeedState, bool>(
      (s) => s.isTranslating(post.id, language),
    );
    final link = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.primary,
    );
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final source = (translation?.sourceLanguage ?? post.lang ?? '')
        .toUpperCase();

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        if (translation != null)
          Text(l10n.xFeedTranslatedFrom(source), style: muted),
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: busy
              ? null
              : () => unawaited(XTranslationActions.toggle(context, post)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              translation != null
                  ? l10n.xFeedShowOriginal
                  : l10n.xFeedTranslate,
              style: link,
            ),
          ),
        ),
        if (busy)
          const SizedBox.square(
            dimension: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}
