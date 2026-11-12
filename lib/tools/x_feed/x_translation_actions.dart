import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import 'models/x_post.dart';
import 'x_feed_state.dart';

abstract final class XTranslationActions {
  /// The X Feed setting, else the app's language. Rebuilds on change, so
  /// call it from `build` only.
  static String targetLanguage(BuildContext context) =>
      context.select<XFeedState, String?>((s) => s.translateTo) ??
      Localizations.localeOf(context).languageCode;

  static String _currentLanguage(BuildContext context) =>
      context.read<XFeedState>().translateTo ??
      Localizations.localeOf(context).languageCode;

  static Future<void> toggle(BuildContext context, XPost post) async {
    if (!post.canTranslate) return;
    final unavailable = AppLocalizations.of(
      context,
    ).xFeedTranslationUnavailable;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await context.read<XFeedState>().toggleTranslation(
      post,
      _currentLanguage(context),
    );
    if (!ok) messenger?.showSnackBar(SnackBar(content: Text(unavailable)));
  }
}
