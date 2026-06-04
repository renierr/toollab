import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

class DeviceInfoTool {
  DeviceInfoTool._();

  static const ToolModel config = ToolModel(
    id: 'device-info',
    name: 'Device Info',
    description: 'Battery, sensors, and system information',
    icon: Icons.phone_android_outlined,
    route: '/device-info',
    accentColor: AppTheme.accentPurple,
  );
}
