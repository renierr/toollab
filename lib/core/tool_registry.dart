import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/tools/calculator/config.dart';
import 'package:tool_lab/tools/bubble_level/config.dart';
import 'package:tool_lab/tools/emf_detector/config.dart';
import 'package:tool_lab/tools/device_info/config.dart';

class ToolRegistry {
  ToolRegistry._();

  static const List<ToolModel> all = [
    CalculatorTool.config,
    BubbleLevelTool.config,
    EmfDetectorTool.config,
    DeviceInfoTool.config,
  ];
}
