import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';
import 'package:tool_lab/widgets/web_login/web_login.dart';

import '../x_login_actions.dart';

/// Shown while no session is stored: every way to get one onto this device.
class XLoginView extends StatelessWidget {
  final bool tvMode;
  final bool expired;

  const XLoginView({super.key, required this.tvMode, this.expired = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // A TV is logged in from a phone first; typing a password by remote is the fallback.
    final pairFirst = tvMode && Platform.isAndroid;

    final web = WebLogin.isSupported
        ? FilledButton.icon(
            autofocus: !pairFirst,
            onPressed: () => XLoginActions.webLogin(context),
            icon: const Icon(Icons.login),
            label: Text(l10n.xFeedLogIn),
          )
        : null;
    final Widget? pair;
    if (pairFirst) {
      pair = FilledButton.icon(
        autofocus: true,
        onPressed: () => XLoginActions.receiveFromPhone(context),
        icon: const Icon(Icons.qr_code_2),
        label: Text(l10n.xFeedPairReceiveTitle),
      );
    } else if (Platform.isAndroid) {
      pair = OutlinedButton.icon(
        onPressed: () => XLoginActions.receiveFromPhone(context),
        icon: const Icon(Icons.qr_code_2),
        label: Text(l10n.xFeedPairReceiveTitle),
      );
    } else {
      pair = null;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ReadableWidth(
          maxWidth: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.dynamic_feed_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                expired ? l10n.xFeedSessionExpired : l10n.xFeedLoginIntro,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.xFeedLoginPrivacy,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              for (final button in pairFirst ? [pair, web] : [web, pair])
                if (button != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: button,
                  ),
              TextButton.icon(
                onPressed: () => XLoginActions.pasteSession(context),
                icon: const Icon(Icons.content_paste),
                label: Text(l10n.xFeedPasteSessionTitle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
