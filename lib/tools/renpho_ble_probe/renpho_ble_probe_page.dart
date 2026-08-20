import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'renpho_ble_probe_state.dart';
import 'renpho_body_image.dart';
import 'renpho_body_metrics.dart';
import 'renpho_report_pdf.dart';
import 'renpho_segment_labels.dart';
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
  bool _creatingReport = false;

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

  /// The report always covers the latest reading, since that is the one the
  /// week's trend ends on.
  Future<void> _createReport() async {
    final state = context.read<RenphoBleProbeState>();
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final latest = state.latest;
    if (latest == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.renphoReportNoMeasurement)));
      return;
    }
    setState(() => _creatingReport = true);
    try {
      final bodyImage = await renderRenphoBodyImage(
        segments: RenphoDerived(latest).segments,
        name: (segment) => segment.label(l10n),
      );
      final bytes = await buildRenphoReportPdf(
        measurement: latest,
        bodyImage: bodyImage,
        weightSeries: state.weeklySeries((m) => m.weightKg),
        bodyFatSeries: state.weeklySeries((m) => m.bodyFatPercent),
        muscleSeries: state.weeklySeries((m) => m.musclePercent),
        waterSeries: state.weeklySeries(
          (m) => RenphoDerived(m).bodyWaterPercent,
        ),
        seriesEnd: DateTime.now(),
        l10n: l10n,
        locale: locale,
      );
      if (!mounted) return;
      await FileSaveHelper.saveFile(
        context: context,
        suggestedName:
            'renpho_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
        bytes: bytes,
      );
    } catch (error) {
      errorLog('RenphoBleProbePage: report failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.renphoReportFailed)));
      }
    } finally {
      if (mounted) setState(() => _creatingReport = false);
    }
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
          tooltip: l10n.renphoReportTooltip,
          icon: _creatingReport
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined),
          onPressed: _creatingReport ? null : _createReport,
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
                      _SectionTitle(
                        title: l10n.renphoSectionLatest,
                        detail: DateFormat.yMMMd(
                          Localizations.localeOf(context).toString(),
                        ).add_Hms().format(latest.measuredAt.toLocal()),
                      ),
                      const SizedBox(height: 8),
                      RenphoMetricsGrid(measurement: latest, showTrends: true),
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
  final String? detail;

  const _SectionTitle({required this.title, this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A Wrap rather than a Row: on a narrow screen the timestamp moves to its
    // own line instead of shrinking the heading.
    return Wrap(
      spacing: 10,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        if (detail != null)
          Text(
            detail!,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
      ],
    );
  }
}
