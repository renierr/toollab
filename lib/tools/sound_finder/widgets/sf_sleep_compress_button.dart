import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';

import '../sleep_session_store.dart';
import '../sleep_sessions_state.dart';
import '../sound_finder_state.dart';

class SfSleepCompressButton extends StatelessWidget {
  const SfSleepCompressButton({super.key, this.session});

  final SleepSession? session;

  Future<void> _compress(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<SleepSessionsState>();
    final messenger = ScaffoldMessenger.of(context);
    final all = session == null;
    final ok = await ConfirmActionDialog.show(
      context: context,
      title: all ? l10n.sfSleepCompressAllTitle : l10n.sfSleepCompressTitle,
      message: l10n.sfSleepCompressBody,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.sfSleepCompress,
    );
    if (ok != true || !context.mounted) return;
    final recorder = context.read<SoundFinderState>().sleep;
    if (recorder.active || recorder.finishing) return;
    try {
      final count = all
          ? await state.compressAll()
          : await state.compress(session!);
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              count == 0
                  ? l10n.sfSleepCompressNone
                  : l10n.sfSleepCompressed(count),
            ),
          ),
        );
      }
    } catch (e) {
      errorLog('[SleepCompression] $e');
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.sfSleepCompressFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (busy, analyzing) = context.select<SleepSessionsState, (bool, bool)>(
      (s) => (
        s.compressing,
        session == null ? s.analyzing : s.analysisProgress(session!.id) != null,
      ),
    );
    final recording = context.select<SoundFinderState, bool>(
      (s) => s.sleep.active || s.sleep.finishing,
    );
    return OutlinedButton.icon(
      icon: const Icon(Icons.compress),
      label: Text(
        busy
            ? l10n.sfSleepCompressing
            : session == null
            ? l10n.sfSleepCompressAll
            : l10n.sfSleepCompress,
      ),
      onPressed: busy || analyzing || recording
          ? null
          : () => _compress(context),
    );
  }
}
