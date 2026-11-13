import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/helpers/text_analysis_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/text_ai/text_ai_action.dart';
import 'package:tool_lab/tools/chat_ai/chat_ai_state.dart';
import 'package:tool_lab/tools/notes/config.dart';

import '../memo/memo_clip.dart';
import '../memo/memo_player.dart';
import '../memo/memo_store.dart';
import '../memo/memo_transcriber.dart';
import '../memo/memo_transcript.dart';
import '../sf_format.dart';
import 'sf_memo_model_dialog.dart';

enum _SheetAction { retranscribe, delete }

/// Transcript of a memo with timestamps, summary and export actions. Starts
/// a transcription when the memo has none yet.
class SfMemoTranscriptSheet extends StatefulWidget {
  final MemoClip clip;
  final MemoPlayer player;

  const SfMemoTranscriptSheet({
    super.key,
    required this.clip,
    required this.player,
  });

  static Future<void> show(
    BuildContext context, {
    required MemoClip clip,
    required MemoPlayer player,
  }) async {
    final transcriber = context.read<MemoTranscriber>();
    await transcriber.init();
    if (!context.mounted) return;
    if (transcriber.model == null && !clip.hasTranscript) {
      if (!await SfMemoModelDialog.show(context)) return;
      if (!context.mounted) return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SfMemoTranscriptSheet(clip: clip, player: player),
    );
  }

  @override
  State<SfMemoTranscriptSheet> createState() => _SfMemoTranscriptSheetState();
}

class _SfMemoTranscriptSheetState extends State<SfMemoTranscriptSheet> {
  MemoTranscript? _transcript;
  bool _loading = true;
  String? _error;
  bool _summarizing = false;
  String _summaryDraft = '';
  StreamSubscription<String>? _summary;
  late final MemoTranscriber _transcriber = context.read<MemoTranscriber>();
  bool _wasRunning = false;

  String get _path => widget.clip.path;

  @override
  void initState() {
    super.initState();
    _wasRunning = _transcriber.isTranscribing(_path);
    _transcriber.addListener(_onTranscriber);
    unawaited(_load());
  }

  @override
  void dispose() {
    _transcriber.removeListener(_onTranscriber);
    _summary?.cancel();
    super.dispose();
  }

  void _onTranscriber() {
    final running = _transcriber.isTranscribing(_path);
    if (_wasRunning && !running) unawaited(_load(start: false));
    _wasRunning = running;
  }

  Future<void> _load({bool start = true}) async {
    final transcript = await MemoTranscript.load(_path);
    if (!mounted) return;
    setState(() {
      _transcript = transcript;
      _loading = false;
    });
    if (start && transcript == null && !_transcriber.isTranscribing(_path)) {
      await _transcribe();
    }
  }

  Future<void> _transcribe() async {
    final l10n = AppLocalizations.of(context);
    if (_transcriber.model == null && !await SfMemoModelDialog.show(context)) {
      return;
    }
    setState(() => _error = null);
    try {
      final transcript = await _transcriber.transcribe(
        widget.clip,
        title: l10n.sfTranscriptNotification,
      );
      if (mounted) setState(() => _transcript = transcript);
    } on MemoTranscriptionCancelled {
      if (mounted && _transcript == null) Navigator.of(context).pop();
    } catch (e) {
      errorLog('[SfMemoTranscriptSheet] transcription failed: $e');
      final reason = '$e'.split('\n').first;
      if (mounted) setState(() => _error = l10n.sfTranscriptFailed(reason));
    }
  }

  Future<void> _summarize() async {
    final transcript = _transcript;
    if (transcript == null || _summarizing) return;
    final ai = context.read<ChatAiState>();
    final text = transcript.text;
    if (!ai.isGenerativeAvailable) {
      await _saveSummary(TextAnalysisHelper.summarize(text));
      return;
    }
    const limit = ChatAiState.maxDocumentContextChars;
    setState(() {
      _summarizing = true;
      _summaryDraft = '';
    });
    _summary = ai
        .streamTextTask(
          instruction: TextAiAction.summarize.instruction!,
          text: text.length > limit ? text.substring(0, limit) : text,
        )
        .listen(
          (chunk) => setState(() => _summaryDraft += chunk),
          onError: (Object e) {
            errorLog('[SfMemoTranscriptSheet] summary failed: $e');
            if (mounted) setState(() => _summarizing = false);
          },
          onDone: () async {
            await _saveSummary(_summaryDraft.trim());
            if (mounted) setState(() => _summarizing = false);
          },
        );
  }

  Future<void> _saveSummary(String summary) async {
    final updated = _transcript?.withSummary(summary.isEmpty ? null : summary);
    if (updated == null) return;
    await updated.save(_path);
    if (mounted) setState(() => _transcript = updated);
  }

  String _export(
    MemoTranscript t,
    AppLocalizations l10n, {
    bool markdown = false,
  }) {
    final buffer = StringBuffer();
    final summary = t.summary;
    if (summary != null) {
      buffer
        ..writeln('## ${l10n.sfTranscriptSummary}')
        ..writeln()
        ..writeln(summary)
        ..writeln()
        ..writeln('## ${l10n.sfTranscriptTitle}')
        ..writeln();
    }
    final lines = t.toPlainText().split('\n');
    buffer.writeln(lines.map((l) => markdown ? '- $l' : l).join('\n'));
    return buffer.toString().trim();
  }

  Future<void> _copy(MemoTranscript t) async {
    final l10n = AppLocalizations.of(context);
    await ClipboardHelper.setText(_export(t, l10n));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.textAiCopied)));
  }

  Future<void> _share(MemoTranscript t) async {
    final l10n = AppLocalizations.of(context);
    await SharePlus.instance.share(
      ShareParams(text: _export(t, l10n), subject: widget.clip.name),
    );
  }

  Future<void> _asNote(MemoTranscript t) async {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final markdown =
        '# ${widget.clip.name}\n\n${_export(t, l10n, markdown: true)}\n';
    final name = '${MemoStore.sanitize(widget.clip.name)}.md';
    final path = await TempFileManager.createFile(
      name,
      bytes: utf8.encode(markdown),
    );
    navigator.pop();
    unawaited(
      router.push(
        NotesTool.config.route,
        extra: SharedData.single(
          SharedFile(path: path, name: name, mimeType: 'text/markdown'),
        ),
      ),
    );
  }

  Future<void> _onMenu(_SheetAction action) async {
    switch (action) {
      case _SheetAction.retranscribe:
        await _transcribe();
      case _SheetAction.delete:
        await MemoTranscript.delete(_path);
        MemoStore.notifyChanged();
        if (mounted) Navigator.of(context).pop();
    }
  }

  void _seek(Duration at) {
    final player = widget.player;
    if (player.isCurrent(_path)) {
      player.seek(at);
    } else {
      unawaited(player.play(_path, from: at));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final transcriber = context.watch<MemoTranscriber>();
    final ai = context.watch<ChatAiState>();
    final running = transcriber.isTranscribing(_path);
    final transcript = _transcript;
    final summary = _summarizing ? _summaryDraft : transcript?.summary;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.sfTranscriptTitle,
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          widget.clip.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (transcript != null && !running)
                    PopupMenuButton<_SheetAction>(
                      onSelected: _onMenu,
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: _SheetAction.retranscribe,
                          child: Text(l10n.sfTranscriptRetranscribe),
                        ),
                        PopupMenuItem(
                          value: _SheetAction.delete,
                          child: Text(l10n.sfTranscriptDelete),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (running)
              _Progress(
                value: transcriber.progress(_path),
                cancelling: transcriber.isCancelling(_path),
                onCancel: () => transcriber.cancel(_path),
              )
            else if (_error != null)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              )
            else if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (transcript != null) ...[
              if (summary != null && summary.isNotEmpty)
                _SummaryBox(
                  text: summary,
                  label: ai.isGenerativeAvailable
                      ? l10n.textAiSummaryTitle
                      : l10n.textToolsSummaryTitle,
                ),
              Flexible(
                child: transcript.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l10n.sfTranscriptEmpty),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: transcript.segments.length,
                        itemBuilder: (context, i) => _SegmentRow(
                          segment: transcript.segments[i],
                          onSeek: _seek,
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: transcript.isEmpty || _summarizing
                          ? null
                          : _summarize,
                      icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                      label: Text(l10n.sfTranscriptSummarize),
                    ),
                    TextButton.icon(
                      onPressed: () => _copy(transcript),
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text(l10n.commonCopy),
                    ),
                    TextButton.icon(
                      onPressed: () => _share(transcript),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: Text(l10n.commonShare),
                    ),
                    FilledButton.icon(
                      onPressed: transcript.isEmpty
                          ? null
                          : () => _asNote(transcript),
                      icon: const Icon(Icons.note_add_outlined, size: 18),
                      label: Text(l10n.sfTranscriptAsNote),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Progress extends StatefulWidget {
  final MemoTranscriptionProgress? value;
  final bool cancelling;
  final VoidCallback onCancel;

  const _Progress({
    required this.value,
    required this.cancelling,
    required this.onCancel,
  });

  @override
  State<_Progress> createState() => _ProgressState();
}

class _ProgressState extends State<_Progress> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    // Re-renders the time estimates between chunk updates.
    _tick = Timer.periodic(const Duration(seconds: 5), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  static String _approx(Duration d, AppLocalizations l10n) {
    if (d.inSeconds < 60) {
      return l10n.sfTranscriptSeconds(d.inSeconds.clamp(5, 59));
    }
    return l10n.sfTranscriptMinutes((d.inSeconds / 60).ceil());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.bodySmall;
    final p = widget.value;
    final total = p?.total ?? 0;
    final remaining = p?.remaining;
    final chunkLeft = p?.currentChunkLeft;
    final status = total == 0
        ? l10n.sfTranscriptPreparing
        : [
            l10n.sfTranscriptChunk(p!.done + 1, total),
            if (remaining != null)
              l10n.sfTranscriptRemaining(_approx(remaining, l10n)),
          ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: p?.fraction),
          const SizedBox(height: 8),
          Text(status, style: style),
          Text(
            widget.cancelling
                ? chunkLeft == null
                      ? l10n.sfTranscriptCancellingUnknown
                      : l10n.sfTranscriptCancelling(_approx(chunkLeft, l10n))
                : l10n.sfTranscribingHint,
            style: style,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: widget.cancelling ? null : widget.onCancel,
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: Text(l10n.sfTranscriptCancel),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String text;
  final String label;

  const _SummaryBox({required this.text, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.25,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            SelectableText(text, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SegmentRow extends StatelessWidget {
  final MemoTranscriptSegment segment;
  final ValueChanged<Duration> onSeek;

  const _SegmentRow({required this.segment, required this.onSeek});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: () => onSeek(segment.start),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            textStyle: theme.textTheme.labelMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          child: Text(formatClock(segment.start)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: SelectableText(
              segment.text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}
