import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'grocery_list_sync_delegate.dart';
import 'grocery_list_page.dart';
import 'grocery_list_state.dart';

class GroceryListTool {
  GroceryListTool._();

  static ToolModel get config => ToolModel(
    id: 'grocery-list',
    name: 'Grocery List',
    description:
        'Create grocery lists with quantities, reusable items, and check-off tracking',
    icon: Icons.shopping_cart_outlined,
    route: '/grocery-list',
    accentColor: AppTheme.accentTeal,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameGroceryList,
    descriptionL10n: (l10n) => l10n.toolDescGroceryList,
    createPage: (_) => const GroceryListPage(),
    syncDelegateFactory: GroceryListSyncDelegate.new,
    stateProviders: () => [
      ChangeNotifierProvider<GroceryListState>(
        create: (_) => GroceryListState(),
      ),
    ],
  );
}
