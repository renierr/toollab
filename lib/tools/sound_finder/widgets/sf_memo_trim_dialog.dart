import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../memo/memo_clip.dart';
import '../sf_format.dart';
import 'sf_memo_waveform.dart';

typedef SfMemoTrimResult = ({Duration start, Duration end, bool asCopy});

/// Picks the part of a WAV memo to keep.
class SfMemoTrimDialog extends StatefulWidget {
  final MemoClip clip;

  const SfMemoTrimDialog({super.key, required this.clip});

  @override
  State<SfMemoTrimDialog> createState() => _SfMemoTrimDialogState();
}

class _SfMemoTrimDialogState extends State<SfMemoTrimDialog> {
  RangeValues _range = const RangeValues(0, 1);

  Duration _at(double f) => widget.clip.duration * f;

  void _submit(bool asCopy) {
    Navigator.pop<SfMemoTrimResult>(context, (
      start: _at(_range.start),
      end: _at(_range.end),
      asCopy: asCopy,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final start = _at(_range.start);
    final end = _at(_range.end);
    final bool changed = _range.start > 0 || _range.end < 1;
    final bool valid = end - start >= const Duration(milliseconds: 100);

    return ResponsiveAlertDialog(
      title: Text(l10n.sfTrimClip),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.clip.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SfMemoWaveform(
              clip: widget.clip,
              height: 64,
              selection: (_range.start, _range.end),
            ),
          ),
          RangeSlider(
            values: _range,
            onChanged: (v) => setState(() => _range = v),
          ),
          Text(
            l10n.sfMemoTrimSelection(
              formatClock(start),
              formatClock(end),
              formatClock(end - start),
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        OutlinedButton(
          onPressed: changed && valid ? () => _submit(false) : null,
          child: Text(l10n.sfMemoTrimReplace),
        ),
        FilledButton(
          onPressed: changed && valid ? () => _submit(true) : null,
          child: Text(l10n.sfMemoTrimSaveCopy),
        ),
      ],
    );
  }
}
