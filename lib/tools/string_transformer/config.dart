import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'string_transformer_page.dart';
import 'string_transformer_state.dart';

class StringTransformerTool {
  StringTransformerTool._();

  static ToolModel get config => ToolModel(
    id: 'string-transformer',
    name: 'String Transformer',
    description:
        'Convert text between various formats: camelCase, snake_case, kebab-case, PascalCase, URL slugs, Base64, Hex, and decode ad URLs.',
    icon: Icons.text_fields_outlined,
    route: '/string-transformer',
    accentColor: AppTheme.accentTeal,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameStringTransformer,
    descriptionL10n: (l10n) => l10n.toolDescStringTransformer,
    shareTarget: const ShareTargetConfig(accept: ['text/*']),
    createPage: (sharedData) => StringTransformerPage(sharedData: sharedData),
    stateProviders: () => [
      ChangeNotifierProvider<StringTransformerState>(
        create: (_) => StringTransformerState(),
      ),
    ],
  );
}
