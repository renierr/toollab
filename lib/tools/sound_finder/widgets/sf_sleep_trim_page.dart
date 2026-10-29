import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/data_row.dart';
import 'package:tool_lab/widgets/readable_width.dart';
import 'package:tool_lab/widgets/sleep_stage_style.dart';

import '../sleep_labels.dart';
import '../sleep_player.dart';
import '../sleep_session_store.dart';
import '../sleep_sessions_state.dart';
import 'sf_sleep_timeline.dart';
import 'sf_sleep_trim_markers.dart';

/// Cuts a session to the part actually slept: everything outside the start
/// and end markers is removed, audio included, here and on the server.
class SfSleepTrimPage extends StatefulWidget {
  const SfSleepTrimPage({super.key, required this.sessionId});

  final String sessionId;

  static Future<void> open(BuildContext context, SleepSession session) {
    final state = context.read<SleepSessionsState>();
    final player = context.read<SleepPlayer>();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: player),
            ChangeNotifierProvider.value(value: state),
          ],
          child: SfSleepTrimPage(sessionId: session.id),
        ),
      ),
    );
  }

  @override
  State<SfSleepTrimPage> createState() => _SfSleepTrimPageState();
}

class _SfSleepTrimPageState extends State<SfSleepTrimPage> {
  static const _step = Duration(minutes: 1);

  DateTime? _from;
  DateTime? _to;
  bool _busy = false;

  Duration _gap(SleepSession s) {
    final half = s.data.duration ~/ 2;
    return half < _step ? half : _step;
  }

  void _setRange(SleepSession s, DateTime from, DateTime to) {
    final start = s.data.startedAt;
    final end = s.data.endedAt;
    final gap = _gap(s);
    DateTime clamp(DateTime t, DateTime lo, DateTime hi) =>
        t.isBefore(lo) ? lo : (t.isAfter(hi) ? hi : t);
    final movedStart = from != (_from ?? start);
    setState(() {
      if (movedStart) {
        _to = clamp(to, start.add(gap), end);
        _from = clamp(from, start, _to!.subtract(gap));
      } else {
        _from = clamp(from, start, end.subtract(gap));
        _to = clamp(to, _from!.add(gap), end);
      }
    });
  }

  Future<void> _auto(SleepSession s) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<SleepSessionsState>();
    setState(() => _busy = true);
    try {
      if (state.healthStages(s.id).isEmpty) await state.loadHealthStages(s);
      final asleep = [
        for (final b in state.healthStages(s.id))
          if (b.kind != SleepStageKind.awake) b,
      ];
      if (!mounted) return;
      if (asleep.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.sfSleepNoStages)));
        return;
      }
      final from = asleep
          .map((b) => b.start)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final to = asleep
          .map((b) => b.end)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      setState(() {
        _from = from;
        _to = to;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply(SleepSession s, DateTime from, DateTime to) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final state = context.read<SleepSessionsState>();
    final cut = s.data.events
        .where((e) => !SleepSessionStore.keepsOnTrim(e, from, to))
        .length;
    final ok = await ConfirmActionDialog.show(
      context: context,
      title: l10n.sfSleepTrimTitle,
      message: l10n.sfSleepTrimConfirmBody(
        cut,
        sleepClock(from, seconds: false),
        sleepClock(to, seconds: false),
      ),
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.sfSleepTrim,
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final removed = await state.trim(s, from, to);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          removed == null ? l10n.sfSleepTrimFailed : l10n.sfSleepTrimDone,
        ),
      ),
    );
    if (removed != null) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = context.select<SleepSessionsState, SleepSession?>(
      (s) => s.sessions.where((e) => e.id == widget.sessionId).firstOrNull,
    );
    final blocked = context.select<SleepSessionsState, bool>(
      (s) =>
          s.analysisProgress(widget.sessionId) != null ||
          s.compressionProgress(widget.sessionId) != null ||
          s.sessions.any((e) => e.id == widget.sessionId && s.isRecording(e)),
    );
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.sfSleepTrimTitle)),
        body: const SizedBox.shrink(),
      );
    }
    final data = session.data;
    final from = _from ?? data.startedAt;
    final to = _to ?? data.endedAt;
    final cut = [
      for (final e in data.events)
        if (!SleepSessionStore.keepsOnTrim(e, from, to)) e,
    ];
    final freed = cut.fold<int>(0, (a, e) => a + (session.sizeOf(e) ?? 0));
    final changed = from != data.startedAt || to != data.endedAt;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sfSleepTrimTitle)),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.sfSleepTrimHint),
            const SizedBox(height: 12),
            SfSleepTimeline(
              session: session,
              foreground: SfSleepTrimMarkers(
                data: data,
                from: from,
                to: to,
                onChanged: (f, t) => _setRange(session, f, t),
              ),
            ),
            const SizedBox(height: 12),
            _MarkerRow(
              label: l10n.sfSleepTrimStart,
              time: from,
              onShift: (d) => _setRange(session, from.add(d), to),
            ),
            _MarkerRow(
              label: l10n.sfSleepTrimEnd,
              time: to,
              onShift: (d) => _setRange(session, from, to.add(d)),
            ),
            const SizedBox(height: 8),
            InfoRow(
              label: l10n.sfSleepTrimKept,
              value: sleepDuration(to.difference(from)),
            ),
            const SizedBox(height: 4),
            InfoRow(
              label: l10n.sfSleepTrimRemovedChunks,
              value: '${cut.length} / ${data.events.length}',
            ),
            const SizedBox(height: 4),
            InfoRow(
              label: l10n.sfSleepTrimFreed,
              value: FormatHelper.fileSize(freed),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.monitor_heart_outlined),
                  label: Text(l10n.sfSleepTrimAuto),
                  onPressed: _busy ? null : () => _auto(session),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.restart_alt),
                  label: Text(l10n.commonReset),
                  onPressed: _busy || !changed
                      ? null
                      : () => setState(() {
                          _from = null;
                          _to = null;
                        }),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.content_cut),
                  label: Text(l10n.sfSleepTrim),
                  onPressed: _busy || blocked || !changed
                      ? null
                      : () => _apply(session, from, to),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkerRow extends StatelessWidget {
  const _MarkerRow({
    required this.label,
    required this.time,
    required this.onShift,
  });

  static const _step = Duration(minutes: 1);

  final String label;
  final DateTime time;
  final ValueChanged<Duration> onShift;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        IconButton(
          tooltip: l10n.sfSleepTrimEarlier,
          icon: const Icon(Icons.remove),
          onPressed: () => onShift(-_step),
        ),
        Text(sleepClock(time), style: theme.textTheme.titleSmall),
        IconButton(
          tooltip: l10n.sfSleepTrimLater,
          icon: const Icon(Icons.add),
          onPressed: () => onShift(_step),
        ),
      ],
    );
  }
}
