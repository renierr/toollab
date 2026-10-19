import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../sleep_sessions_state.dart';
import 'sf_sleep_overview_card.dart';
import 'sf_sleep_session_tile.dart';
import 'sf_sleep_sync_button.dart';

class SfSleepSessionsPage extends StatelessWidget {
  const SfSleepSessionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SleepSessionsState(),
      child: const _SleepSessionsScaffold(),
    );
  }
}

class _SleepSessionsScaffold extends StatelessWidget {
  const _SleepSessionsScaffold();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SleepSessionsState>();
    final sessions = state.sessions;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sfSleepSessionsTitle),
        actions: const [SfSleepSyncButton()],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : sessions.isEmpty
          ? Center(child: Text(l10n.sfSleepNoSessions))
          : ReadableWidth(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: sessions.length + 1,
                itemBuilder: (context, i) => i == 0
                    ? const SfSleepOverviewCard()
                    : SfSleepSessionTile(
                        key: ValueKey(sessions[i - 1].id),
                        session: sessions[i - 1],
                      ),
              ),
            ),
    );
  }
}
