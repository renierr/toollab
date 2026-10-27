import 'package:tool_lab/services/sync_service.dart';

import 'config.dart';
import 'depot_store.dart';
import 'models/depot_wishlist.dart';

class DepotWishlistSyncDelegate
    with DefaultSyncDelegate
    implements SyncDelegate {
  final _store = DepotStore.instance;
  final Map<String, int> _observed = {};

  @override
  String get toolId => DepotTool.config.id;

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecords() async {
    final records = await _store.wishlistSyncRecords();
    _observed.addAll({
      for (final record in records) record.symbol: record.updatedAt,
    });
    return [
      for (final record in records)
        {
          'id': record.symbol,
          'updatedAt': record.updatedAt,
          'deleted': record.deleted,
        },
    ];
  }

  @override
  Future<Map<String, dynamic>?> getLocalRecordData(String id) async {
    final item = await _store.wishlistItem(id);
    if (item == null) return null;
    return {
      'shortId': item.symbol,
      'name': item.name,
      'quoteType': item.quoteType,
      'exchange': item.exchange,
      'currency': item.currency,
      'isin': item.isin,
      'addedPrice': item.addedPrice,
      'addedAt': item.addedAt.millisecondsSinceEpoch,
    };
  }

  @override
  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  }) async {
    if (deleted) {
      final observed = _observed[id];
      if (observed != null) await _store.finalizeWishlistDeletion(id, observed);
      return;
    }
    await _store.savePulledWishlistItem(
      DepotWishlistItem(
        symbol: id,
        name: data['name'] as String,
        quoteType: data['quoteType'] as String,
        exchange: data['exchange'] as String,
        currency: data['currency'] as String,
        isin: data['isin'] as String?,
        addedPrice: (data['addedPrice'] as num?)?.toDouble(),
        addedAt: DateTime.fromMillisecondsSinceEpoch(data['addedAt'] as int),
      ),
      updatedAt,
    );
  }

  @override
  Future<void> finalizeLocalSync(String id, bool wasDeleted) async {
    final observed = _observed[id];
    if (wasDeleted && observed != null) {
      await _store.finalizeWishlistDeletion(id, observed);
    }
  }
}
