import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'qr_code_page.dart';
import 'qr_code_state.dart';

class QrCodeTool {
  QrCodeTool._();

  static ToolModel get config => ToolModel(
    id: 'qr-code',
    name: 'QR Code',
    description:
        'Scan QR codes with the camera or an image, and create your own',
    icon: Icons.qr_code_scanner_outlined,
    route: '/qr-code',
    accentColor: AppTheme.accentPurple,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameQrCode,
    descriptionL10n: (l10n) => l10n.toolDescQrCode,
    fileExtensions: ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'],
    createPage: (_) => const QrCodePage(),
    stateProviders: () => [
      ChangeNotifierProvider<QrCodeState>(create: (_) => QrCodeState()),
    ],
  );
}
