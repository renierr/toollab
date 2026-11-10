import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/web_login/web_login.dart';

import 'api/x_session.dart';
import 'widgets/x_pair_receive_dialog.dart';
import 'widgets/x_session_dialog.dart';
import 'x_feed_state.dart';

class XLoginActions {
  XLoginActions._();

  static final Uri _loginUrl = Uri.parse('https://x.com/i/flow/login');
  static final Uri _cookieUrl = Uri.parse('https://x.com');

  static Future<void> webLogin(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<XFeedState>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    // Start signed out, or the page would reuse a session the app dropped.
    await WebLogin.clearCookies();
    if (!context.mounted) return;
    final result = await WebLogin.open(
      context,
      url: _loginUrl,
      title: l10n.xFeedLoginTitle,
      target: WebLoginTarget.cookies(
        cookieUrl: _cookieUrl,
        isComplete: (cookies) => XSession.fromCookies(cookies) != null,
      ),
    );
    if (result is! WebLoginCookies) return;
    final session = XSession.fromCookies(result.cookies);
    if (session == null) return;
    await state.signIn(session);
    messenger?.showSnackBar(SnackBar(content: Text(l10n.xFeedLoggedIn)));
  }

  static Future<void> pasteSession(BuildContext context) async {
    final session = await XSessionDialog.show(context);
    if (session == null || !context.mounted) return;
    await context.read<XFeedState>().signIn(session);
  }

  static Future<void> receiveFromPhone(BuildContext context) async {
    final session = await XPairReceiveDialog.show(context);
    if (session == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    await context.read<XFeedState>().signIn(session);
    messenger?.showSnackBar(SnackBar(content: Text(l10n.xFeedLoggedIn)));
  }
}
