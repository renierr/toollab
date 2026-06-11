import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'focus_noise_page.dart';

class FocusNoiseTool {
  FocusNoiseTool._();

  static ToolModel get config => ToolModel(
    id: 'focus-noise',
    name: 'Focus Noise & Breathing',
    description: 'Ambient noise player with guided breathing patterns',
    icon: Icons.waves_outlined,
    route: '/focus-noise',
    accentColor: AppTheme.accentBlue,
    sectionId: 'utilities',
    createPage: (_) => const FocusNoisePage(),
  );
}
