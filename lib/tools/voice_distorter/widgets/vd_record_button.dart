import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/theme.dart';
import '../engine/voice_recorder.dart';
import '../voice_distorter_state.dart';

/// Starts recording and surfaces a permission/availability snackbar on
/// failure. Shared by the record button and the transport bar's re-record
/// action.
Future<void> startRecordingWithFeedback(BuildContext context) async {
  final state = context.read<VoiceDistorterState>();
  final l10n = AppLocalizations.of(context);
  final result = await state.startRecording();
  if (!context.mounted || result == RecordStartResult.ok) return;
  final message = result == RecordStartResult.denied
      ? l10n.voiceDistorterMicDenied
      : l10n.voiceDistorterMicUnavailable;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// The big record control. Clip mode: tap to start, tap again to stop. Live
/// mode: press and hold — releasing stops the recording and immediately
/// plays it back with the current effect (handled in the state).
class VdRecordButton extends StatelessWidget {
  const VdRecordButton({super.key});

  Future<void> _stop(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final result = await context.read<VoiceDistorterState>().stopRecording();
    if (!context.mounted || result == RecordStopResult.ok) return;
    final message = result == RecordStopResult.tooShort
        ? l10n.voiceDistorterClipTooShort
        : l10n.voiceDistorterClipFailed;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleStop(BuildContext context) => unawaited(_stop(context));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<VoiceDistorterState>();
    final bool recording = state.isRecording;
    final bool live = state.mode == VoiceDistorterMode.live;

    final String hint = recording
        ? l10n.voiceDistorterRecording
        : live
        ? l10n.voiceDistorterHoldToTalk
        : l10n.voiceDistorterTapToRecord;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: state.recordLevel,
          builder: (context, level, child) {
            final double ringScale = recording ? 1.0 + level * 0.35 : 1.0;
            return GestureDetector(
              onTap: live
                  ? null
                  : () => recording
                        ? _handleStop(context)
                        : startRecordingWithFeedback(context),
              onTapDown: live
                  ? (_) => startRecordingWithFeedback(context)
                  : null,
              onTapUp: live ? (_) => _handleStop(context) : null,
              onTapCancel: live ? () => _handleStop(context) : null,
              child: SizedBox(
                width: 128,
                height: 128,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedScale(
                      scale: ringScale,
                      duration: const Duration(milliseconds: 80),
                      child: Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              (recording
                                      ? AppTheme.statusRed
                                      : theme.colorScheme.primary)
                                  .withAlpha(40),
                        ),
                      ),
                    ),
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: recording
                            ? AppTheme.statusRed
                            : theme.colorScheme.primary,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (recording
                                        ? AppTheme.statusRed
                                        : theme.colorScheme.primary)
                                    .withAlpha(90),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Icon(
                        recording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: theme.colorScheme.onPrimary,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(hint, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
