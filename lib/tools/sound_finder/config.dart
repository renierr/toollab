import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'memo/memo_recorder.dart';
import 'sleep_sync_delegate.dart';
import 'sound_finder_page.dart';
import 'sound_finder_state.dart';

class SoundFinderTool {
  SoundFinderTool._();

  static ToolModel get config => ToolModel(
    id: 'sound-finder',
    name: 'Audio Lab',
    description: 'Locate, mask, analyze, and generate audio signals',
    icon: Icons.hearing_outlined,
    route: '/sound-finder',
    accentColor: AppTheme.accentPurple,
    sectionId: 'sensors',
    nameL10n: (l10n) => l10n.toolNameAudioLab,
    descriptionL10n: (l10n) => l10n.toolDescAudioLab,
    stateProviders: () => [
      ChangeNotifierProvider<MemoRecorder>(create: (_) => MemoRecorder()),
      ChangeNotifierProvider<SoundFinderState>(
        create: (context) =>
            SoundFinderState(memo: context.read<MemoRecorder>()),
      ),
    ],
    syncDelegateFactory: () => SleepSyncDelegate(),
    createPage: (_) => const SoundFinderPage(),
  );
}
