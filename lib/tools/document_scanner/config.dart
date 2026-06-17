import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/tools/document_scanner/document_scanner_page.dart';
import 'package:tool_lab/tools/document_scanner/document_scanner_state.dart';

class DocumentScannerTool {
  DocumentScannerTool._();

  static ToolModel get config => ToolModel(
    id: 'document-scanner',
    name: 'Document Scanner',
    description:
        'Scan documents via camera, adjust crop/skew, apply filters, and compile to PDF',
    icon: Icons.scanner_outlined,
    route: '/document-scanner',
    accentColor: AppTheme.accentTeal,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameDocumentScanner,
    descriptionL10n: (l10n) => l10n.toolDescDocumentScanner,
    stateProviders: () => [
      ChangeNotifierProvider<DocumentScannerState>(
        create: (_) => DocumentScannerState(),
      ),
    ],
    createPage: (_) => const DocumentScannerPage(),
  );
}
