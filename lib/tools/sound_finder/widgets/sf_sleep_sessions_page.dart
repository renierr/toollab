import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../sleep_cloud_audio.dart';
import '../sleep_player.dart';
import '../sleep_session_store.dart';
import '../sleep_sessions_state.dart';
import 'sf_sleep_overview_card.dart';
import 'sf_sleep_session_tile.dart';
import 'sf_sleep_sync_button.dart';

class SfSleepSessionsPage extends StatelessWidget {
  const SfSleepSessionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(
          create: (context) =>
              SleepCloudAudio.fromAppState(context.read<AppState>()),
          dispose: (_, SleepCloudAudio audio) => audio.dispose(),
        ),
        ChangeNotifierProvider(
          create: (context) => SleepPlayer(
            resolveAudio: context.read<SleepCloudAudio>().fileFor,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => SleepSessionsState(context.read<SleepPlayer>()),
        ),
      ],
      child: const _SleepSessionsScaffold(),
    );
  }
}

class _SleepSessionsScaffold extends StatelessWidget {
  const _SleepSessionsScaffold();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (loading, sessions) = context
        .select<SleepSessionsState, (bool, List<SleepSession>)>(
          (s) => (s.loading, s.sessions),
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sfSleepSessionsTitle),
        actions: const [SfSleepSyncButton()],
      ),
      body: loading
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
