import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';

import '../memo/memo_library_state.dart';
import '../memo/memo_recorder.dart';
import '../sf_format.dart';
import 'sf_memo_level_view.dart';
import 'sf_memo_settings_dialog.dart';

/// Record / pause / stop / discard controls with the live meter.
class SfMemoRecorderCard extends StatelessWidget {
  const SfMemoRecorderCard({super.key});

  Future<void> _start(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await context.read<MemoLibraryState>().player.stop();
    if (!context.mounted) return;
    final result = await context.read<MemoRecorder>().start();
    if (result == MemoStartResult.failed) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.sfMemoStartFailed)));
    }
  }

  Future<void> _stop(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final path = await context.read<MemoRecorder>().stop();
    if (path == null) return;
    final name = path.split(RegExp(r'[\\/]')).last;
    messenger.showSnackBar(SnackBar(content: Text(l10n.sfMemoSaved(name))));
  }

  Future<void> _discard(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final memo = context.read<MemoRecorder>();
    final ok = await ConfirmActionDialog.show(
      context: context,
      title: l10n.sfMemoDiscardTitle,
      message: l10n.sfMemoDiscardBody,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.sfMemoDiscard,
    );
    if (ok == true) await memo.discard();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final memo = context.watch<MemoRecorder>();
    final s = memo.settings;
    final bool active = memo.isActive;
    final bool busy =
        memo.status == MemoStatus.starting ||
        memo.status == MemoStatus.stopping;

    final String statusText = switch (memo.status) {
      MemoStatus.recording => l10n.sfMemoRecording,
      MemoStatus.paused => l10n.sfMemoPaused,
      _ => l10n.sfMemoReady,
    };
    final Color statusColor = switch (memo.status) {
      MemoStatus.recording => AppTheme.statusRed,
      MemoStatus.paused => AppTheme.statusAmber,
      _ => theme.colorScheme.onSurfaceVariant,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      active ? Icons.fiber_manual_record : Icons.mic_none,
                      size: 18,
                      color: statusColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: active ? statusColor : null,
                      ),
                    ),
                  ],
                ),
                ActionChip(
                  avatar: const Icon(Icons.tune_outlined, size: 18),
                  label: Text(
                    '${s.format.label} · ${formatRate(s.sampleRate)} · '
                    '${s.channels == 2 ? l10n.sfMemoStereo : l10n.sfMemoMono}',
                  ),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const SfMemoSettingsDialog(),
                  ),
                ),
              ],
            ),
            if (memo.permissionDenied && !active) ...[
              const SizedBox(height: 12),
              Text(
                l10n.sfMemoDeniedBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.statusAmber,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (active)
              SfMemoLevelView(levels: memo.levels, paused: memo.isPaused)
            else
              Text(
                l10n.sfMemoHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (active) ...[
                  IconButton.outlined(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.sfMemoDiscard,
                    onPressed: busy ? null : () => _discard(context),
                  ),
                  const SizedBox(width: 24),
                ],
                _RoundRecordButton(
                  recording: active,
                  busy: busy,
                  tooltip: active ? l10n.sfStopAndSave : l10n.sfRecordClip,
                  onPressed: () => active ? _stop(context) : _start(context),
                ),
                if (active) ...[
                  const SizedBox(width: 24),
                  IconButton.filledTonal(
                    icon: Icon(memo.isPaused ? Icons.mic : Icons.pause),
                    tooltip: memo.isPaused
                        ? l10n.sfResumeRecording
                        : l10n.sfPauseRecording,
                    onPressed: busy
                        ? null
                        : () {
                            final m = context.read<MemoRecorder>();
                            memo.isPaused ? m.resume() : m.pause();
                          },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundRecordButton extends StatelessWidget {
  final bool recording;
  final bool busy;
  final String tooltip;
  final VoidCallback onPressed;

  const _RoundRecordButton({
    required this.recording,
    required this.busy,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final onColor = Theme.of(context).colorScheme.onError;
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 72,
        child: FilledButton(
          style: FilledButton.styleFrom(
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            backgroundColor: AppTheme.statusRed,
            foregroundColor: onColor,
          ),
          onPressed: busy ? null : onPressed,
          child: busy
              ? const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              : Icon(recording ? Icons.stop_rounded : Icons.mic, size: 34),
        ),
      ),
    );
  }
}
