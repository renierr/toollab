import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'calculator_page.dart';

class CalculatorTool {
  CalculatorTool._();

  static ToolModel get config => ToolModel(
    id: 'calculator',
    name: 'Calculator',
    description: 'Basic and scientific calculations',
    icon: Icons.calculate_outlined,
    route: '/calculator',
    accentColor: AppTheme.accentBlue,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameCalculator,
    descriptionL10n: (l10n) => l10n.toolDescCalculator,
    createPage: (_) => const CalculatorPage(),
  );
}
