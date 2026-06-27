import 'package:flutter/material.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'grocery_item.dart';
import 'grocery_list_db_helper.dart';
import 'grocery_list_sync_delegate.dart';

class GroceryListState extends ChangeNotifier {
  List<GroceryItem> _items = [];
  List<String> _history = [];
  bool _isLoading = false;

  List<GroceryItem> get items => _items;
  List<String> get history => _history;
  bool get isLoading => _isLoading;

  Future<void> loadItems() async {
    _isLoading = true;
    notifyListeners();
    try {
      _items = await GroceryListDbHelper.instance.getActiveItems();
      final historyRows = await GroceryListDbHelper.instance.getHistory();
      _history = historyRows.map((r) => r['name'] as String).toList();
    } catch (e) {
      debugPrint('[GroceryListState] Failed to load grocery list items: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveItem(GroceryItem item) async {
    await GroceryListDbHelper.instance.saveItem(item);
    await loadItems();
    _backgroundSync();
  }

  Future<void> deleteItem(int id) async {
    await GroceryListDbHelper.instance.softDeleteItem(id);
    await loadItems();
    _backgroundSync();
  }

  Future<void> clearCheckedItems() async {
    await GroceryListDbHelper.instance.clearCheckedItems();
    await loadItems();
    _backgroundSync();
  }

  Future<void> reAddCheckedItems() async {
    await GroceryListDbHelper.instance.reAddCheckedItems();
    await loadItems();
    _backgroundSync();
  }

  Future<Map<String, int>> importFromJson(
    List<Map<String, dynamic>> itemsList,
  ) async {
    final List<GroceryItem> parsed = [];
    for (final map in itemsList) {
      final name = map['name'] as String? ?? '';
      if (name.trim().isEmpty) continue;

      parsed.add(
        GroceryItem(
          shortId: map['shortId'] as String? ?? '',
          name: name,
          amount: (map['amount'] as num?)?.toDouble() ?? 1.0,
          unit: map['unit'] as String? ?? 'pcs',
          checked: map['checked'] as bool? ?? false,
          createdAt: map['createdAt'] as int? ?? 0,
          updatedAt: map['updatedAt'] as int? ?? 0,
        ),
      );
    }

    final results = await GroceryListDbHelper.instance.importItems(parsed);
    await loadItems();
    _backgroundSync();
    return results;
  }

  void _backgroundSync() {
    _doBackgroundSync().catchError((e) {
      debugPrint('[GroceryListState] Background sync failed: $e');
    });
  }

  Future<void> _doBackgroundSync() async {
    final syncEnabled = await DatabaseService.instance.getSetting(
      '_app',
      'sync_enabled',
    );
    if (syncEnabled != 'true') return;
    final serverUrl = await DatabaseService.instance.getSetting(
      '_app',
      'sync_server_url',
    );
    if (serverUrl == null || serverUrl.isEmpty) return;
    final userId =
        await DatabaseService.instance.getSetting('_app', 'sync_user_id') ?? '';

    await SyncService.sync(
      baseUrl: serverUrl,
      userId: userId,
      delegate: GroceryListSyncDelegate(),
    );
  }
}
