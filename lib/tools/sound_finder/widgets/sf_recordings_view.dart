import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../memo/memo_library_state.dart';
import '../memo/memo_player.dart';
import '../memo/memo_recorder.dart';
import '../sf_format.dart';
import 'sf_memo_clip_tile.dart';
import 'sf_memo_recorder_card.dart';

/// Memo recorder tab: the recorder on top, stored memos below.
class SfRecordingsView extends StatelessWidget {
  const SfRecordingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MemoPlayer>(create: (_) => MemoPlayer()),
        ChangeNotifierProvider<MemoLibraryState>(
          create: (context) => MemoLibraryState(context.read<MemoPlayer>()),
        ),
      ],
      child: const _MemoList(),
    );
  }
}

class _MemoList extends StatefulWidget {
  const _MemoList();

  @override
  State<_MemoList> createState() => _MemoListState();
}

class _MemoListState extends State<_MemoList> {
  @override
  void initState() {
    super.initState();
    final memo = context.read<MemoRecorder>();
    final player = context.read<MemoPlayer>();
    unawaited(
      memo.init().then((_) => player.setSpeed(memo.settings.playbackSpeed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final library = context.watch<MemoLibraryState>();
    final clips = library.clips;

    return ReadableWidth(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: clips.isEmpty ? 3 : clips.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) return const SfMemoRecorderCard();
          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text(
                clips.isEmpty
                    ? l10n.sfTitleRecordings
                    : l10n.sfMemoListSummary(
                        clips.length,
                        formatBytes(library.totalBytes),
                      ),
                style: theme.textTheme.titleMedium,
              ),
            );
          }
          if (clips.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: library.loading
                  ? const Center(child: CircularProgressIndicator())
                  : Text(
                      l10n.sfMemoEmpty,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
            );
          }
          final clip = clips[index - 2];
          return SfMemoClipTile(key: ValueKey(clip.path), clip: clip);
        },
      ),
    );
  }
}
