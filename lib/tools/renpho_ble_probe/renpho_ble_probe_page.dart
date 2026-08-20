import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'renpho_ble_probe_state.dart';
import 'widgets/renpho_history_list.dart';
import 'widgets/renpho_metrics_grid.dart';
import 'widgets/renpho_profile_dialog.dart';
import 'widgets/renpho_scan_card.dart';
import 'widgets/renpho_settings_sheet.dart';
import 'widgets/renpho_trends.dart';

class RenphoBleProbePage extends StatefulWidget {
  const RenphoBleProbePage({super.key});

  @override
  State<RenphoBleProbePage> createState() => _RenphoBleProbePageState();
}

class _RenphoBleProbePageState extends State<RenphoBleProbePage>
    with DisposeCleanup<RenphoBleProbePage> {
  @override
  void initState() {
    super.initState();
    final state = context.read<RenphoBleProbeState>();
    onDispose(state.disconnect);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await state.load();
      if (!mounted) return;
      state.backgroundSync();
    });
  }

  /// Scanning without a profile would attribute a body composition to invented
  /// defaults, so the first scan asks for one and only then starts.
  Future<void> _scan() async {
    final state = context.read<RenphoBleProbeState>();
    if (state.busy || state.connected) {
      await state.disconnect();
      return;
    }
    if (!state.profileConfigured) {
      final profile = await RenphoProfileDialog.show(
        context,
        profile: state.profile,
        firstRun: true,
      );
      if (profile == null) return;
      await state.saveProfile(profile);
    }
    await state.startScan();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RenphoBleProbeState>();
    final l10n = AppLocalizations.of(context);
    final latest = state.latest;

    return ToolLayout(
      title: RenphoBleProbeTool.config.localizedName(l10n),
      actions: [
        IconButton(
          tooltip: l10n.renphoSyncNow,
          icon: state.syncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_sync_outlined),
          onPressed: state.syncing ? null : state.syncNow,
        ),
        IconButton(
          tooltip: l10n.renphoSettingsTitle,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => RenphoSettingsSheet.show(context),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: state.refreshHistory,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RenphoScanCard(onScan: _scan),
                    const SizedBox(height: 20),
                    if (latest != null) ...[
                      _SectionTitle(title: l10n.renphoSectionLatest),
                      const SizedBox(height: 8),
                      RenphoMetricsGrid(measurement: latest),
                      const SizedBox(height: 24),
                    ],
                    const RenphoTrends(),
                    const SizedBox(height: 24),
                    _SectionTitle(title: l10n.renphoSectionHistory),
                    const SizedBox(height: 8),
                    const RenphoHistoryList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) =>
      Text(title, style: Theme.of(context).textTheme.titleMedium);
}
