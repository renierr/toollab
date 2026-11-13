import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'translator_page.dart';
import 'translator_state.dart';

class TranslatorTool {
  TranslatorTool._();

  static ToolModel get config => ToolModel(
    id: 'translator',
    name: 'Translator',
    description:
        'Translate text offline from typing, photos and speech, and read the result aloud.',
    icon: Icons.translate,
    route: '/translator',
    accentColor: AppTheme.accentBlue,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameTranslator,
    descriptionL10n: (l10n) => l10n.toolDescTranslator,
    shareTarget: const ShareTargetConfig(accept: ['text/*']),
    createPage: (sharedData) => TranslatorPage(sharedData: sharedData),
    onClose: (context) => context.read<TranslatorState>().release(),
    stateProviders: () => [
      ChangeNotifierProvider<TranslatorState>(create: (_) => TranslatorState()),
    ],
  );
}
