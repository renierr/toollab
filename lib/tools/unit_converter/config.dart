import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'unit_converter_page.dart';
import 'unit_converter_state.dart';

class UnitConverterTool {
  UnitConverterTool._();

  static ToolModel get config => ToolModel(
    id: 'unit-converter',
    name: 'Unit Converter',
    description: 'Convert between units across many categories',
    icon: Icons.swap_horiz,
    route: '/unit-converter',
    accentColor: AppTheme.accentPurple,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameUnitConverter,
    descriptionL10n: (l10n) => l10n.toolDescUnitConverter,
    createPage: (sharedData) => UnitConverterPage(sharedData: sharedData),
    stateProviders: () => [
      ChangeNotifierProvider<UnitConverterState>(
        create: (_) => UnitConverterState(),
      ),
    ],
  );
}
