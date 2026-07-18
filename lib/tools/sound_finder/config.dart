import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

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
      ChangeNotifierProvider<SoundFinderState>(
        create: (_) => SoundFinderState(),
      ),
    ],
    createPage: (_) => const SoundFinderPage(),
  );
}
