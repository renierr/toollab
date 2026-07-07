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
    name: 'Sound Finder',
    description: 'Locate, mask and generate room sounds with the microphone',
    icon: Icons.hearing_outlined,
    route: '/sound-finder',
    accentColor: AppTheme.accentPurple,
    sectionId: 'sensors',
    nameL10n: (l10n) => l10n.toolNameSoundFinder,
    descriptionL10n: (l10n) => l10n.toolDescSoundFinder,
    stateProviders: () => [
      ChangeNotifierProvider<SoundFinderState>(
        create: (_) => SoundFinderState(),
      ),
    ],
    createPage: (_) => const SoundFinderPage(),
  );
}
