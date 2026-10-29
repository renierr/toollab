import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'depot_background_sync.dart';
import 'depot_allocation_state.dart';
import 'depot_dividend_state.dart';
import 'depot_import_state.dart';
import 'depot_holding_trend_state.dart';
import 'depot_logo_state.dart';
import 'depot_page.dart';
import 'depot_portfolio_state.dart';
import 'depot_state.dart';
import 'depot_wishlist_state.dart';
import 'depot_wishlist_sync_delegate.dart';

class DepotTool {
  DepotTool._();

  static ToolModel get config => ToolModel(
    id: 'depot',
    name: 'Depot',
    description: 'Portfolio overview and broker PDF import for Parqet',
    icon: Icons.account_balance_outlined,
    route: '/depot',
    accentColor: AppTheme.accentGreen,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameDepot,
    descriptionL10n: (l10n) => l10n.toolDescDepot,
    androidProcessIsolated: true,
    fileExtensions: const ['pdf'],
    shareTarget: const ShareTargetConfig(accept: ['application/pdf']),
    createPage: (sd) => DepotPage(sharedFile: sd?.firstFile),
    syncDelegateFactory: DepotWishlistSyncDelegate.new,
    stateProviders: () => [
      ChangeNotifierProvider<DepotState>(create: (_) => DepotState()),
      ChangeNotifierProvider<DepotPortfolioState>(
        create: (_) => DepotPortfolioState(),
      ),
      ChangeNotifierProvider<DepotAllocationState>(
        create: (_) => DepotAllocationState(),
      ),
      ChangeNotifierProvider<DepotDividendState>(
        create: (_) => DepotDividendState(),
      ),
      ChangeNotifierProvider<DepotLogoState>(create: (_) => DepotLogoState()),
      ChangeNotifierProvider<DepotHoldingTrendState>(
        create: (_) => DepotHoldingTrendState(),
      ),
      ChangeNotifierProvider<DepotWishlistState>(
        create: (_) => DepotWishlistState(),
      ),
      ChangeNotifierProvider<DepotImportState>(
        create: (_) => DepotImportState(),
      ),
    ],
    backgroundTasks: () => [DepotBackgroundSync.task],
  );
}
