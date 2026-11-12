import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import 'models/x_post.dart';
import 'x_feed_state.dart';

abstract final class XTranslationActions {
  static Future<void> toggle(BuildContext context, XPost post) async {
    if (!post.canTranslate) return;
    final unavailable = AppLocalizations.of(
      context,
    ).xFeedTranslationUnavailable;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await context.read<XFeedState>().translator.toggle(post);
    if (!ok) messenger?.showSnackBar(SnackBar(content: Text(unavailable)));
  }
}
