import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

class EmfDetectorTool {
  EmfDetectorTool._();

  static const ToolModel config = ToolModel(
    id: 'emf-detector',
    name: 'EMF Detector',
    description: 'Detect electromagnetic fields',
    icon: Icons.wifi_tethering_outlined,
    route: '/emf-detector',
    accentColor: AppTheme.accentAmber,
  );
}
