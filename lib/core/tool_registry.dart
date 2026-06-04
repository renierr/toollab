import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/tools/calculator/config.dart';
import 'package:tool_lab/tools/bubble_level/config.dart';
import 'package:tool_lab/tools/emf_detector/config.dart';
import 'package:tool_lab/tools/device_info/config.dart';

class ToolRegistry {
  ToolRegistry._();

  static const Map<String, ToolSection> sections = {
    'sensors': ToolSection(
      id: 'sensors',
      title: 'Sensors',
      icon: Icons.sensors,
      description: 'Tools using device sensors',
    ),
    'utilities': ToolSection(
      id: 'utilities',
      title: 'Utilities',
      icon: Icons.build_outlined,
    ),
    'info': ToolSection(
      id: 'info',
      title: 'Information',
      icon: Icons.info_outline,
    ),
  };

  static const List<ToolModel> all = [
    CalculatorTool.config,
    BubbleLevelTool.config,
    EmfDetectorTool.config,
    DeviceInfoTool.config,
  ];
}
