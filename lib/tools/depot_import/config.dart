import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'depot_import_page.dart';
import 'depot_import_state.dart';

class DepotImportTool {
  DepotImportTool._();

  static ToolModel get config => ToolModel(
    id: 'depot-import',
    name: 'Depot Import',
    description: 'Turn DKB and ING depot PDFs into a Parqet CSV import file',
    icon: Icons.account_balance_outlined,
    route: '/depot-import',
    accentColor: AppTheme.accentGreen,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameDepotImport,
    descriptionL10n: (l10n) => l10n.toolDescDepotImport,
    fileExtensions: const ['pdf'],
    shareTarget: const ShareTargetConfig(accept: ['application/pdf']),
    createPage: (sd) => DepotImportPage(sharedFile: sd?.firstFile),
    stateProviders: () => [
      ChangeNotifierProvider<DepotImportState>(
        create: (_) => DepotImportState(),
      ),
    ],
  );
}
