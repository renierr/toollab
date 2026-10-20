import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';

import '../sleep_session_store.dart';
import '../sleep_sessions_state.dart';

class SfSleepSessionActions extends StatelessWidget {
  const SfSleepSessionActions({super.key, required this.session});

  final SleepSession session;

  Future<void> _loadStages(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final found = await context.read<SleepSessionsState>().loadHealthStages(
      session,
    );
    if (!found) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.sfSleepNoStages)));
    }
  }

  Future<void> _export(BuildContext context) async {
    final data = session.data;
    final report = <String, dynamic>{
      'session': session.id,
      ...data.toJson(),
      'summary': {
        'durationSeconds': data.duration.inSeconds,
        'recordedSeconds': data.recordedDuration.inSeconds,
        'chunkCount': data.events.length,
        'avgPeakDb': data.avgPeakDb,
        'loudestDb': data.loudestDb,
        'wavBytes': session.wavBytes,
        'jsonBytes': session.jsonBytes,
      },
    };
    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: '${session.id}_report.json',
      bytes: Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(report)),
      ),
    );
  }

  Future<void> _pdf(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await context.read<SleepSessionsState>().reportPdf(
        session,
        l10n,
        locale,
      );
      if (!context.mounted) return;
      await FileSaveHelper.saveFile(
        context: context,
        suggestedName: '${session.id}_report.pdf',
        bytes: bytes,
      );
    } catch (e) {
      errorLog('SfSleepSessionActions: pdf report failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.sfSleepPdfFailed)));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<SleepSessionsState>();
    final ok = await ConfirmActionDialog.show(
      context: context,
      title: l10n.sfSleepDeleteTitle,
      message: l10n.sfSleepDeleteBody(session.data.events.length),
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.commonDelete,
    );
    if (ok == true) await state.delete(session);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.read<SleepSessionsState>();
    final (analyzing, healthLoading, reportBusy) = context
        .select<SleepSessionsState, (bool, bool, bool)>(
          (s) => (
            s.analysisProgress(session.id) != null,
            s.healthLoading(session.id),
            s.reportBusy(session.id),
          ),
        );
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.monitor_heart_outlined),
          label: Text(l10n.sfSleepLoadStages),
          onPressed: healthLoading ? null : () => _loadStages(context),
        ),
        if (session.data.isAnalyzed && session.data.events.isNotEmpty)
          OutlinedButton.icon(
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(l10n.sfSleepReanalyze),
            onPressed: analyzing ? null : () => state.analyze(session),
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(l10n.sfSleepPdfReport),
          onPressed: reportBusy ? null : () => _pdf(context),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.save_alt_outlined),
          label: Text(l10n.sfSleepExportReport),
          onPressed: () => _export(context),
        ),
        TextButton.icon(
          icon: const Icon(Icons.delete_outline),
          label: Text(l10n.commonDelete),
          onPressed: () => _delete(context),
        ),
      ],
    );
  }
}
