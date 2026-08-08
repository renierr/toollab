import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/tools/grocery_list/config.dart';
import 'grocery_list_db_helper.dart';

class GroceryListSyncDelegate with DefaultSyncDelegate implements SyncDelegate {
  @override
  String get toolId => GroceryListTool.config.id;

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecords() async {
    final records = await GroceryListDbHelper.instance.getSyncRecords();
    return records
        .map(
          (r) => {
            'id': r['short_id'] as String,
            'updatedAt': r['updated_at'] as int,
            'deleted': (r['deleted'] as int) == 1,
          },
        )
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> getLocalRecordData(String id) async {
    final item = await GroceryListDbHelper.instance.getItemByShortId(id);
    if (item == null || item.deleted) return null;
    return {
      'shortId': item.shortId,
      'name': item.name,
      'amount': item.amount,
      'unit': item.unit,
      'checked': item.checked,
      'createdAt': item.createdAt,
      'updatedAt': item.updatedAt,
    };
  }

  @override
  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  }) async {
    await GroceryListDbHelper.instance.savePulledItem(
      shortId: id,
      name: data['name'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 1.0,
      unit: data['unit'] as String? ?? 'pcs',
      checked: data['checked'] as bool? ?? false,
      createdAt: data['createdAt'] as int? ?? updatedAt,
      updatedAt: updatedAt,
      deleted: deleted,
    );
  }

  @override
  Future<void> finalizeLocalSync(String id, bool wasDeleted) async {
    if (wasDeleted) {
      await GroceryListDbHelper.instance.hardDeleteItem(id);
    } else {
      await GroceryListDbHelper.instance.markSynced(id);
    }
  }
}
