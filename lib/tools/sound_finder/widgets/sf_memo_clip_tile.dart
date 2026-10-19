import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/file_name_dialog.dart';

import '../memo/memo_clip.dart';
import '../memo/memo_library_state.dart';
import '../memo/memo_player.dart';
import '../memo/memo_recorder.dart';
import '../sf_format.dart';
import 'sf_memo_trim_dialog.dart';
import 'sf_memo_waveform.dart';

enum _ClipAction { rename, share, save, trim, normalize, delete }

class SfMemoClipTile extends StatelessWidget {
  final MemoClip clip;

  const SfMemoClipTile({super.key, required this.clip});

  static const List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  Future<void> _onAction(BuildContext context, _ClipAction action) async {
    final l10n = AppLocalizations.of(context);
    final library = context.read<MemoLibraryState>();
    final messenger = ScaffoldMessenger.of(context);
    void report(bool ok, [String? success]) {
      if (!ok) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.sfMemoEditFailed)));
      } else if (success != null) {
        messenger.showSnackBar(SnackBar(content: Text(success)));
      }
    }

    switch (action) {
      case _ClipAction.rename:
        final name = await showDialog<String>(
          context: context,
          builder: (_) => FileNameDialog(
            title: l10n.sfMemoRenameTitle,
            initialValue: clip.name,
          ),
        );
        if (name != null && name.trim() != clip.name) {
          report(await library.rename(clip, name));
        }
      case _ClipAction.share:
        await FileSaveHelper.showShareChooser(
          context: context,
          path: clip.path,
          mimeType: clip.mimeType,
        );
      case _ClipAction.save:
        await FileSaveHelper.saveFileFromPath(
          context: context,
          suggestedName: clip.fileName,
          sourcePath: clip.path,
          successMessageAndroid: l10n.sfClipSavedAndroid,
          successMessageGeneralBuilder: (path) => l10n.sfClipSaved(path),
          errorMessageBuilder: (_) => l10n.sfClipSaveError,
        );
      case _ClipAction.trim:
        final result = await showDialog<SfMemoTrimResult>(
          context: context,
          builder: (_) => SfMemoTrimDialog(clip: clip),
        );
        if (result != null) {
          report(
            await library.trim(
              clip,
              result.start,
              result.end,
              asCopy: result.asCopy,
            ),
          );
        }
      case _ClipAction.normalize:
        report(await library.normalize(clip), l10n.sfMemoNormalized);
      case _ClipAction.delete:
        final ok = await ConfirmActionDialog.show(
          context: context,
          title: l10n.sfMemoDeleteTitle,
          message: l10n.sfMemoDeleteBody(clip.name),
          cancelLabel: l10n.commonCancel,
          confirmLabel: l10n.commonDelete,
        );
        if (ok == true) report(await library.delete(clip));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final library = context.watch<MemoLibraryState>();
    final player = context.watch<MemoPlayer>();
    final bool current = player.isCurrent(clip.path);
    final bool playing = player.isPlaying(clip.path);
    final bool busy = library.isBusy(clip.path);
    final localizations = MaterialLocalizations.of(context);
    final String when =
        '${localizations.formatShortDate(clip.modified)} '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(clip.modified))}';
    final String specs = [
      clip.extension.toUpperCase(),
      if (clip.sampleRate > 0) formatRate(clip.sampleRate),
      if (clip.channels == 1) l10n.sfMemoMono,
      if (clip.channels == 2) l10n.sfMemoStereo,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  tooltip: playing ? l10n.sfMemoPausePlayback : l10n.sfPlayClip,
                  onPressed: busy ? null : () => player.toggle(clip.path),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clip.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: current ? AppTheme.statusGreen : null,
                        ),
                      ),
                      Text(
                        '$when · ${formatClock(clip.duration)} · '
                        '${formatBytes(clip.sizeBytes)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        specs,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  PopupMenuButton<_ClipAction>(
                    onSelected: (a) => _onAction(context, a),
                    itemBuilder: (_) => [
                      _item(
                        _ClipAction.rename,
                        Icons.edit_outlined,
                        l10n.commonRename,
                      ),
                      _item(
                        _ClipAction.share,
                        Icons.share_outlined,
                        l10n.commonShare,
                      ),
                      _item(
                        _ClipAction.save,
                        Icons.download_outlined,
                        l10n.sfMemoSaveTo,
                      ),
                      if (clip.editable) ...[
                        _item(
                          _ClipAction.trim,
                          Icons.content_cut,
                          l10n.sfTrimClip,
                        ),
                        _item(
                          _ClipAction.normalize,
                          Icons.auto_fix_high,
                          l10n.sfNormalizeClip,
                        ),
                      ],
                      _item(
                        _ClipAction.delete,
                        Icons.delete_outline,
                        l10n.commonDelete,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 8),
              child: SfMemoWaveform(
                clip: clip,
                position: current ? player.position : null,
                length: current ? player.length : clip.duration,
                onSeek: busy
                    ? null
                    : (f) {
                        if (current) {
                          player.seek(player.length * f);
                        } else {
                          player.play(clip.path, from: clip.duration * f);
                        }
                      },
              ),
            ),
            if (current) _PlaybackBar(player: player, speeds: _speeds),
          ],
        ),
      ),
    );
  }

  PopupMenuEntry<_ClipAction> _item(
    _ClipAction value,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem(
      value: value,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(label),
      ),
    );
  }
}

class _PlaybackBar extends StatelessWidget {
  final MemoPlayer player;
  final List<double> speeds;

  const _PlaybackBar({required this.player, required this.speeds});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tabular = theme.textTheme.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, top: 4),
      child: Row(
        children: [
          ValueListenableBuilder<Duration>(
            valueListenable: player.position,
            builder: (_, pos, _) => Text(formatClock(pos), style: tabular),
          ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.replay_5),
            tooltip: l10n.sfMemoSkipBack,
            onPressed: () => player.skip(const Duration(seconds: -5)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.forward_5),
            tooltip: l10n.sfMemoSkipForward,
            onPressed: () => player.skip(const Duration(seconds: 5)),
          ),
          PopupMenuButton<double>(
            tooltip: l10n.sfPlaybackSpeed,
            initialValue: player.speed,
            onSelected: (s) {
              player.setSpeed(s);
              final memo = context.read<MemoRecorder>();
              memo.updateSettings(memo.settings.copyWith(playbackSpeed: s));
            },
            itemBuilder: (_) => [
              for (final s in speeds)
                PopupMenuItem(value: s, child: Text('${_speedLabel(s)}×')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Text(
                '${_speedLabel(player.speed)}×',
                style: theme.textTheme.labelLarge,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.stop),
            tooltip: l10n.sfStop,
            onPressed: player.stop,
          ),
          const Spacer(),
          Text(formatClock(player.length), style: tabular),
        ],
      ),
    );
  }

  static String _speedLabel(double s) =>
      s == s.roundToDouble() ? s.toStringAsFixed(0) : '$s';
}
