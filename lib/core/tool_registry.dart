import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/calculator/config.dart';
import 'package:tool_lab/tools/bubble_level/config.dart';
import 'package:tool_lab/tools/emf_detector/config.dart';
import 'package:tool_lab/tools/device_info/config.dart';
import 'package:tool_lab/tools/nfc_tag_lab/config.dart';
import 'package:tool_lab/tools/pdf_viewer/config.dart';
import 'package:tool_lab/tools/notes/config.dart';
import 'package:tool_lab/tools/grocery_list/config.dart';
import 'package:tool_lab/tools/markdown_viewer/config.dart';
import 'package:tool_lab/tools/image_viewer/config.dart';
import 'package:tool_lab/tools/fast_drop/config.dart';
import 'package:tool_lab/tools/images_to_pdf/config.dart';
import 'package:tool_lab/tools/chiptune/config.dart';
import 'package:tool_lab/tools/focus_noise/config.dart';
import 'package:tool_lab/tools/signatures/config.dart';
import 'package:tool_lab/tools/qr_code/config.dart';
import 'package:tool_lab/tools/document_scanner/config.dart';
import 'package:tool_lab/tools/gps_location_store/config.dart';
import 'package:tool_lab/tools/chat_ai/config.dart';
import 'package:tool_lab/tools/hex_editor/config.dart';
import 'package:tool_lab/tools/file_converter/config.dart';
import 'package:tool_lab/tools/sketch_board/config.dart';
import 'package:tool_lab/tools/unit_converter/config.dart';
import 'package:tool_lab/tools/code_highlight/config.dart';
import 'package:tool_lab/tools/bluetooth_scanner/config.dart';
import 'package:tool_lab/tools/renpho_ble_probe/config.dart';
import 'package:tool_lab/tools/string_transformer/config.dart';
import 'package:tool_lab/tools/treadmill_control/config.dart';
import 'package:tool_lab/tools/sound_finder/config.dart';
import 'package:tool_lab/tools/compass/config.dart';
import 'package:tool_lab/tools/file_manager/config.dart';
import 'package:tool_lab/tools/health_dashboard/config.dart';
import 'package:tool_lab/tools/sqlite_viewer/config.dart';
import 'package:tool_lab/tools/text_editor/config.dart';

class ToolRegistry {
  static final Map<String, ToolSection> sections = {
    'sensors': ToolSection(
      id: 'sensors',
      title: 'Sensors',
      icon: Icons.sensors,
      description: 'Tools using device sensors',
      titleL10n: (AppLocalizations l10n) => l10n.sectionTitleSensors,
    ),
    'utilities': ToolSection(
      id: 'utilities',
      title: 'Utilities',
      icon: Icons.build_outlined,
      titleL10n: (AppLocalizations l10n) => l10n.sectionTitleUtilities,
    ),
    'info': ToolSection(
      id: 'info',
      title: 'Information',
      icon: Icons.info_outline,
      titleL10n: (AppLocalizations l10n) => l10n.sectionTitleInfo,
    ),
  };

  static final List<ToolModel> all = [
    CalculatorTool.config,
    BubbleLevelTool.config,
    CompassTool.config,
    EmfDetectorTool.config,
    SoundFinderTool.config,
    DeviceInfoTool.config,
    NfcTagLabTool.config,
    PdfViewerTool.config,
    NotesTool.config,
    GroceryListTool.config,
    MarkdownViewerTool.config,
    ImageViewerTool.config,
    FastDropTool.config,
    ImagesToPdfTool.config,
    ChiptuneTool.config,
    FocusNoiseTool.config,
    SignaturesTool.config,
    QrCodeTool.config,
    DocumentScannerTool.config,
    GpsLocationStoreTool.config,
    ChatAiTool.config,
    HexEditorTool.config,
    SqliteViewerTool.config,
    FileConverterTool.config,
    SketchBoardTool.config,
    UnitConverterTool.config,
    CodeHighlightTool.config,
    BluetoothScannerTool.config,
    RenphoBleProbeTool.config,
    StringTransformerTool.config,
    TreadmillControlTool.config,
    HealthDashboardTool.config,
    FileManagerTool.config,
    TextEditorTool.config,
  ];
}
