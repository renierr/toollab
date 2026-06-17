import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'nfc_tag_lab_page.dart';

class NfcTagLabTool {
  NfcTagLabTool._();

  static ToolModel get config => ToolModel(
    id: 'nfc-tag-lab',
    name: 'NFC Tag Lab',
    description:
        'Scan NFC targets, decode NDEF, classify signatures, and write tags.',
    icon: Icons.nfc_outlined,
    route: '/nfc-tag-lab',
    accentColor: AppTheme.accentTeal,
    sectionId: 'sensors',
    nameL10n: (l10n) => l10n.toolNameNfcTagLab,
    descriptionL10n: (l10n) => l10n.toolDescNfcTagLab,
    createPage: (_) => const NfcTagLabPage(),
  );
}
