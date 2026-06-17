import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'device_info_page.dart';

class DeviceInfoTool {
  DeviceInfoTool._();

  static ToolModel get config => ToolModel(
    id: 'device-info',
    name: 'Device Info',
    description: 'Battery, sensors, and system information',
    icon: Icons.phone_android_outlined,
    route: '/device-info',
    accentColor: AppTheme.accentPurple,
    sectionId: 'info',
    nameL10n: (l10n) => l10n.toolNameDeviceInfo,
    descriptionL10n: (l10n) => l10n.toolDescDeviceInfo,
    createPage: (_) => const DeviceInfoPage(),
  );
}
