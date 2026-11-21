import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'models/weather_cache_entry.dart';
import 'models/weather_history_entry.dart';
import 'models/weather_location.dart';

class WeatherDbHelper {
  WeatherDbHelper._();
  static final WeatherDbHelper instance = WeatherDbHelper._();

  static const String _locations = 'locations';
  static const String _cache = 'cache';
  static const String _history = 'history';

  Future<ToolDatabase>? _db;

  Future<ToolDatabase> _getDb() => _db ??= _open();

  Future<ToolDatabase> _open() async {
    final db = await DatabaseService.instance.getToolDatabase(
      WeatherTool.config.id,
    );
    try {
      await db.migrate(
        currentVersion: 3,
        onMigrate: (txn, oldVersion, newVersion) async {
          if (oldVersion < 1) {
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(_locations)} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                latitude REAL NOT NULL,
                longitude REAL NOT NULL,
                elevation REAL,
                is_device INTEGER NOT NULL DEFAULT 0,
                forecast_station TEXT,
                observation_station TEXT,
                sort_order INTEGER NOT NULL DEFAULT 0
              )
            ''');
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(_cache)} (
                key TEXT PRIMARY KEY,
                body BLOB NOT NULL,
                fetched_at INTEGER NOT NULL
              )
            ''');
          }
          if (oldVersion < 2) {
            // One row per place and hour; WITHOUT ROWID keeps it compact.
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(_history)} (
                location_id INTEGER NOT NULL,
                hour INTEGER NOT NULL,
                source INTEGER NOT NULL,
                temperature REAL,
                dew_point REAL,
                pressure REAL,
                wind_speed REAL,
                wind_gust REAL,
                wind_direction REAL,
                precipitation REAL,
                cloud_cover REAL,
                sunshine REAL,
                condition TEXT,
                PRIMARY KEY (location_id, hour)
              ) WITHOUT ROWID
            ''');
          }
          if (oldVersion < 3) {
            await txn.execute(
              'ALTER TABLE ${txn.nameTable(_locations)} ADD COLUMN station_url TEXT',
            );
          }
        },
      );
    } catch (e) {
      errorLog('[WeatherDbHelper] Migration failed: $e');
    }
    return db;
  }

  /// Test hook: forget the cached connection after the database was swapped.
  void reset() => _db = null;

  Future<List<WeatherLocation>> getLocations() async {
    final db = await _getDb();
    final rows = await db.query(_locations, orderBy: 'sort_order ASC, id ASC');
    return rows.map(WeatherLocation.fromMap).toList();
  }

  Future<WeatherLocation> saveLocation(WeatherLocation location) async {
    final db = await _getDb();
    if (location.id != null) {
      await db.update(
        _locations,
        location.toMap(),
        where: 'id = ?',
        whereArgs: [location.id],
      );
      return location;
    }
    final next = await db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next FROM ${db.nameTable(_locations)}',
    );
    final withOrder = location.copyWith(
      sortOrder: next.first['next'] as int? ?? 0,
    );
    final id = await db.insert(_locations, withOrder.toMap());
    return withOrder.copyWith(id: id);
  }

  Future<void> deleteLocation(int id) async {
    final db = await _getDb();
    // History stays until the next prune, so an undo keeps it.
    await db.delete(_locations, where: 'id = ?', whereArgs: [id]);
  }

  /// Puts a deleted place back under its old id, so its history follows.
  Future<WeatherLocation> restoreLocation(WeatherLocation location) async {
    final db = await _getDb();
    await db.insert(
      _locations,
      location.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return location;
  }

  Future<void> reorder(List<int> ids) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      for (var i = 0; i < ids.length; i++) {
        await txn.update(
          _locations,
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [ids[i]],
        );
      }
    });
  }

  Future<WeatherCacheEntry?> getCache(String key) async {
    final db = await _getDb();
    final rows = await db.query(
      _cache,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : WeatherCacheEntry.fromMap(rows.first);
  }

  Future<void> putCache(String key, Uint8List body, DateTime fetchedAt) async {
    final db = await _getDb();
    await db.insert(_cache, {
      'key': key,
      'body': body,
      'fetched_at': fetchedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Drops every saved download, including radar maps; places stay.
  Future<void> clearCache() async {
    final db = await _getDb();
    await db.delete(_cache);
  }

  Future<void> pruneCache(DateTime olderThan, {String prefix = ''}) async {
    final db = await _getDb();
    await db.delete(
      _cache,
      where: 'fetched_at < ? AND key LIKE ?',
      whereArgs: [olderThan.millisecondsSinceEpoch, '$prefix%'],
    );
  }

  /// Measurements replace whatever is stored; forecast values only fill hours
  /// nothing was measured for.
  Future<void> recordHistory(List<WeatherHistoryEntry> entries) async {
    if (entries.isEmpty) return;
    final db = await _getDb();
    final batch = db.batch();
    for (final e in entries) {
      batch.insert(
        _history,
        e.toMap(),
        conflictAlgorithm: e.isMeasured
            ? ConflictAlgorithm.replace
            : ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Hours in `[from, to)`, oldest first.
  Future<List<WeatherHistoryEntry>> getHistory(
    int locationId,
    DateTime from,
    DateTime to,
  ) async {
    final db = await _getDb();
    final rows = await db.query(
      _history,
      where: 'location_id = ? AND hour >= ? AND hour < ?',
      whereArgs: [
        locationId,
        from.millisecondsSinceEpoch ~/ 1000,
        to.millisecondsSinceEpoch ~/ 1000,
      ],
      orderBy: 'hour ASC',
    );
    return rows.map(WeatherHistoryEntry.fromMap).toList();
  }

  Future<int> historyCount() async {
    final db = await _getDb();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${db.nameTable(_history)}',
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Drops hours before [before] (null keeps them) and hours of deleted places.
  Future<void> pruneHistory(DateTime? before) async {
    final db = await _getDb();
    if (before != null) {
      await db.delete(
        _history,
        where: 'hour < ?',
        whereArgs: [before.millisecondsSinceEpoch ~/ 1000],
      );
    }
    await db.delete(
      _history,
      where: 'location_id NOT IN (SELECT id FROM ${db.nameTable(_locations)})',
    );
  }

  Future<void> clearHistory() async {
    final db = await _getDb();
    await db.delete(_history);
  }
}
