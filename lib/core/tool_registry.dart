import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/tools/calculator/config.dart';
import 'package:tool_lab/tools/bubble_level/config.dart';
import 'package:tool_lab/tools/emf_detector/config.dart';
import 'package:tool_lab/tools/device_info/config.dart';
import 'package:tool_lab/tools/nfc_tag_lab/config.dart';
import 'package:tool_lab/tools/pdf_viewer/config.dart';
import 'package:tool_lab/tools/notes/config.dart';
import 'package:tool_lab/tools/markdown_viewer/config.dart';
import 'package:tool_lab/tools/image_viewer/config.dart';
import 'package:tool_lab/tools/fast_drop/config.dart';
import 'package:tool_lab/tools/images_to_pdf/config.dart';
import 'package:tool_lab/tools/chiptune/config.dart';
import 'package:tool_lab/tools/focus_noise/config.dart';

class ToolRegistry {
  static const Map<String, ToolSection> sections = {
    'sensors': ToolSection(
      id: 'sensors',
      title: 'Sensors',
      icon: Icons.sensors,
      description: 'Tools using device sensors',
    ),
    'devices': ToolSection(
      id: 'devices',
      title: 'Devices & Connections',
      icon: Icons.nfc_outlined,
      description: 'NFC, Bluetooth, and device connections',
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

  static List<ToolModel> get all => [
    CalculatorTool.config,
    BubbleLevelTool.config,
    EmfDetectorTool.config,
    DeviceInfoTool.config,
    NfcTagLabTool.config,
    PdfViewerTool.config,
    NotesTool.config,
    MarkdownViewerTool.config,
    ImageViewerTool.config,
    FastDropTool.config,
    ImagesToPdfTool.config,
    ChiptuneTool.config,
    FocusNoiseTool.config,
  ];
}
