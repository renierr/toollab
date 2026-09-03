import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'voice_distorter_page.dart';
import 'voice_distorter_state.dart';

class VoiceDistorterTool {
  VoiceDistorterTool._();

  static ToolModel get config => ToolModel(
    id: 'voice-distorter',
    name: 'Voice Distorter',
    description: 'Record a voice clip and remix it with fun voice effects',
    icon: Icons.record_voice_over_outlined,
    route: '/voice-distorter',
    accentColor: AppTheme.accentPurple,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameVoiceDistorter,
    descriptionL10n: (l10n) => l10n.toolDescVoiceDistorter,
    createPage: (_) => const VoiceDistorterPage(),
    stateProviders: () => [
      ChangeNotifierProvider<VoiceDistorterState>(
        create: (_) => VoiceDistorterState(),
      ),
    ],
  );
}
