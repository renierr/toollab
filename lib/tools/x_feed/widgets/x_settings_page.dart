import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/readable_width.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';
import 'package:tool_lab/widgets/web_login/web_login.dart';

import '../x_feed_state.dart';
import '../x_login_actions.dart';
import 'x_pair_send_page.dart';

class XSettingsPage extends StatelessWidget {
  const XSettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.xFeedLogOut,
      message: l10n.xFeedLogOutBody,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.xFeedLogOut,
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<XFeedState>().signOut();
  }

  Future<void> _refreshConfig(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<XFeedState>().refreshApiConfig();
      messenger.showSnackBar(SnackBar(content: Text(l10n.xFeedApiRefreshed)));
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.xFeedErrorUnsupported)),
      );
    }
  }

  String _tabLabel(AppLocalizations l10n, XFeedTab tab) => switch (tab) {
    XFeedTab.forYou => l10n.xFeedForYou,
    XFeedTab.following => l10n.xFeedFollowing,
    XFeedTab.bookmarks => l10n.xFeedBookmarks,
    XFeedTab.search => l10n.commonSearch,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<XFeedState>();
    final loggedIn = state.status == XSessionStatus.loggedIn;
    final session = state.session;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.xFeedSettingsTitle)),
      body: ReadableScrollPadding(
        maxWidth: 680,
        padding: const EdgeInsets.only(bottom: 32),
        builder: (context, padding) => ListView(
          padding: padding,
          children: [
            SettingsSectionLabel(
              title: l10n.xFeedAccountSection,
              description: l10n.xFeedLoginPrivacy,
            ),
            if (loggedIn)
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(
                  state.screenName == null
                      ? l10n.xFeedLoggedIn
                      : l10n.xFeedLoggedInAs(state.screenName!),
                ),
                trailing: TextButton(
                  onPressed: () => _logout(context),
                  child: Text(l10n.xFeedLogOut),
                ),
              ),
            if (WebLogin.isSupported)
              ListTile(
                leading: const Icon(Icons.login),
                title: Text(loggedIn ? l10n.xFeedLogInAgain : l10n.xFeedLogIn),
                subtitle: Text(l10n.xFeedLogInSubtitle),
                onTap: () => XLoginActions.webLogin(context),
              ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: Text(l10n.xFeedPasteSessionTitle),
              subtitle: Text(l10n.xFeedPasteSessionSubtitle),
              onTap: () => XLoginActions.pasteSession(context),
            ),
            if (Platform.isAndroid)
              ListTile(
                leading: const Icon(Icons.qr_code_2),
                title: Text(l10n.xFeedPairReceiveTitle),
                subtitle: Text(l10n.xFeedPairReceiveSubtitle),
                onTap: () => XLoginActions.receiveFromPhone(context),
              ),
            if (Platform.isAndroid && session != null)
              ListTile(
                leading: const Icon(Icons.tv),
                title: Text(l10n.xFeedPairSendTitle),
                subtitle: Text(l10n.xFeedPairSendSubtitle),
                onTap: () => XPairSendPage.open(context, session),
              ),
            SettingsSectionLabel(title: l10n.xFeedFeedSection),
            ListTile(
              leading: const Icon(Icons.start),
              title: Text(l10n.xFeedStartTab),
              trailing: DropdownButton<XFeedTab>(
                value: state.startTab,
                onChanged: (tab) {
                  if (tab != null) state.setStartTab(tab);
                },
                items: [
                  for (final tab in XFeedTab.values.where(
                    (t) => t != XFeedTab.search,
                  ))
                    DropdownMenuItem(
                      value: tab,
                      child: Text(_tabLabel(l10n, tab)),
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.format_size),
              title: Text(l10n.xFeedTextSize),
              trailing: DropdownButton<double>(
                value: state.textScale,
                onChanged: (scale) {
                  if (scale != null) state.setTextScale(scale);
                },
                items: [
                  for (final scale in XFeedState.textScales)
                    DropdownMenuItem(
                      value: scale,
                      child: Text(
                        l10n.xFeedTextSizePercent((scale * 100).round()),
                      ),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.repeat),
              title: Text(l10n.xFeedHideReposts),
              value: state.hideReposts,
              onChanged: state.setHideReposts,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.reply),
              title: Text(l10n.xFeedHideReplies),
              value: state.hideReplies,
              onChanged: state.setHideReplies,
            ),
            if (loggedIn) ...[
              SettingsSectionLabel(
                title: l10n.xFeedAdvancedSection,
                description: l10n.xFeedApiRefreshHint,
              ),
              ListTile(
                leading: const Icon(Icons.sync),
                title: Text(l10n.xFeedApiRefresh),
                onTap: () => _refreshConfig(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
