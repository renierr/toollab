import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'depot_import_state.dart';
import 'depot_portfolio_state.dart';
import 'depot_state.dart';
import 'widgets/depot_activities_view.dart';
import 'widgets/depot_dividends_view.dart';
import 'widgets/depot_import_view.dart';
import 'widgets/depot_overview_view.dart';
import 'widgets/depot_settings_page.dart';
import 'widgets/depot_tabs.dart';

class DepotPage extends StatefulWidget {
  final SharedFile? sharedFile;

  const DepotPage({super.key, this.sharedFile});

  @override
  State<DepotPage> createState() => _DepotPageState();
}

class _DepotPageState extends State<DepotPage> with DisposeCleanup {
  // Owned by the page, not the import tab: a tab switch must not delete PDFs
  // that are still being read.
  late final TempFileScope _scope;

  @override
  void initState() {
    super.initState();
    _scope = TempFileManager.createScope();
    onDispose(() => _scope.cleanTracked());

    final importState = context.read<DepotImportState>();
    onDispose(() => Future.microtask(importState.clear));

    final portfolioState = context.read<DepotPortfolioState>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shared = widget.sharedFile;
      if (shared != null) _loadSharedFile(shared);
      portfolioState.syncIfStale();
    });

    final sharingSub = SharingService.instance.onSharedFile.listen(
      _loadSharedFile,
    );
    onDispose(sharingSub.cancel);
  }

  void _loadSharedFile(SharedFile file) {
    context.read<DepotState>().setTab(DepotTab.pdfImport);
    context.read<DepotImportState>().addFiles([
      (path: file.path, name: file.name),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tab = context.select<DepotState, DepotTab>((s) => s.tab);

    return ToolLayout(
      title: switch (tab) {
        DepotTab.overview => DepotTool.config.localizedName(l10n),
        DepotTab.dividends => l10n.depotTabDividends,
        DepotTab.activities => l10n.depotTabActivities,
        DepotTab.pdfImport => l10n.depotTabImport,
      },
      actions: [
        if (tab != DepotTab.pdfImport)
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.depotSettingsTitle,
            onPressed: () => DepotSettingsPage.open(context),
          ),
      ],
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: DepotTabs(),
          ),
          Expanded(
            child: switch (tab) {
              DepotTab.overview => const DepotOverviewView(),
              DepotTab.dividends => const DepotDividendsView(),
              DepotTab.activities => const DepotActivitiesView(),
              DepotTab.pdfImport => DepotImportView(tempScope: _scope),
            },
          ),
        ],
      ),
    );
  }
}
