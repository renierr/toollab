import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

class CalculatorTool {
  CalculatorTool._();

  static const ToolModel config = ToolModel(
    id: 'calculator',
    name: 'Calculator',
    description: 'Basic and scientific calculations',
    icon: Icons.calculate_outlined,
    route: '/calculator',
    accentColor: AppTheme.accentBlue,
  );
}
