import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'emf_detector_page.dart';

class EmfDetectorTool {
  EmfDetectorTool._();

  static ToolModel get config => ToolModel(
    id: 'emf-detector',
    name: 'EMF Detector',
    description: 'Detect electromagnetic fields',
    icon: Icons.wifi_tethering_outlined,
    route: '/emf-detector',
    accentColor: AppTheme.accentAmber,
    sectionId: 'sensors',
    nameL10n: (l10n) => l10n.toolNameEmfDetector,
    descriptionL10n: (l10n) => l10n.toolDescEmfDetector,
    createPage: (_) => const EmfDetectorPage(),
  );
}
