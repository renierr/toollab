import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/gps_location_store/config.dart';
import 'package:tool_lab/tools/gps_location_store/saved_location.dart';
import 'package:tool_lab/tools/gps_location_store/location_source.dart';

class GpsLocationStoreDbHelper {
  static const String tableName = 'locations';

  GpsLocationStoreDbHelper._privateConstructor();
  static final GpsLocationStoreDbHelper instance =
      GpsLocationStoreDbHelper._privateConstructor();

  ToolDatabase? _cachedDb;

  Future<ToolDatabase> _getDb() async {
    if (_cachedDb != null) return _cachedDb!;
    _cachedDb = await DatabaseService.instance.getToolDatabase(
      GpsLocationStoreTool.config.id,
    );
    try {
      await _cachedDb!.migrate(
        currentVersion: 1,
        onMigrate: (txn, oldVersion, newVersion) async {
          if (oldVersion < 1) {
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(tableName)} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                latitude REAL NOT NULL,
                longitude REAL NOT NULL,
                accuracy REAL,
                description TEXT NOT NULL DEFAULT '',
                source TEXT NOT NULL DEFAULT 'gps',
                created_at INTEGER NOT NULL
              )
            ''');
          }
        },
      );
    } catch (e) {
      errorLog('[GpsLocationStoreDbHelper] Migration failed: $e');
    }
    return _cachedDb!;
  }

  /// All stored locations, newest first.
  Future<List<SavedLocation>> getLocations() async {
    final db = await _getDb();
    final rows = await db.query(tableName, orderBy: 'created_at DESC');
    return rows
        .map((r) => SavedLocation.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<int> insertLocation({
    required double latitude,
    required double longitude,
    required double? accuracy,
    required String description,
    required LocationSource source,
  }) async {
    final db = await _getDb();
    return await db.insert(tableName, {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'description': description,
      'source': source.dbValue,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateDescription(int id, String description) async {
    final db = await _getDb();
    await db.update(
      tableName,
      {'description': description},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteLocation(int id) async {
    final db = await _getDb();
    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAll() async {
    final db = await _getDb();
    await db.delete(tableName);
  }
}
