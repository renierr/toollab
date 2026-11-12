import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'x_feed_state.dart';
import 'widgets/x_feed_shell.dart';
import 'widgets/x_login_view.dart';
import 'widgets/x_settings_page.dart';

class XFeedPage extends StatefulWidget {
  const XFeedPage({super.key});

  @override
  State<XFeedPage> createState() => _XFeedPageState();
}

class _XFeedPageState extends State<XFeedPage> with DisposeCleanup {
  @override
  void initState() {
    super.initState();
    final state = context.read<XFeedState>();
    unawaited(state.init());
    final lifecycle = AppLifecycleListener(onHide: state.persistSeen);
    onDispose(lifecycle.dispose);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<XFeedState>().translator.setAppLanguage(
      Localizations.localeOf(context).languageCode,
    );
  }

  Future<void> _refresh() async {
    final state = context.read<XFeedState>();
    if (state.tab == XFeedTab.search) return;
    await state.controllerFor(state.tab).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<XFeedState>();
    final tvMode = context.select<AppState, bool>((s) => s.tvMode);
    final loggedIn = state.status == XSessionStatus.loggedIn;

    return ToolLayout(
      title: XFeedTool.config.localizedName(l10n),
      actions: [
        if (loggedIn && state.tab != XFeedTab.search)
          IconButton(
            onPressed: _refresh,
            tooltip: l10n.xFeedRefresh,
            icon: const Icon(Icons.refresh),
          ),
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const XSettingsPage()),
          ),
          tooltip: l10n.commonSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      child: switch (state.status) {
        XSessionStatus.unknown => const Center(
          child: CircularProgressIndicator(),
        ),
        XSessionStatus.loggedOut => XLoginView(tvMode: tvMode),
        XSessionStatus.loggedIn => const XFeedShell(),
      },
    );
  }
}
