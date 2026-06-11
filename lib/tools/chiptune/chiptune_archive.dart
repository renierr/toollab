import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:tool_lab/services/database_service.dart';

/// A module stored in the archive.
class ArchivedModule {
  final String id;
  final String fileName;
  final String format;
  final String title;
  final int channels;
  final int archivedAt;

  const ArchivedModule({
    required this.id,
    required this.fileName,
    required this.format,
    required this.title,
    required this.channels,
    required this.archivedAt,
  });
}

/// Persists archived modules and exposes the records needed for backend sync.
class ChiptuneArchive {
  static const String toolId = 'chiptune';
  static const String tableName = 'modules';

  ChiptuneArchive._();
  static final ChiptuneArchive instance = ChiptuneArchive._();

  ToolDatabase? _cachedDb;

  Future<ToolDatabase> _getDb() async {
    if (_cachedDb != null) return _cachedDb!;
    _cachedDb = await DatabaseService.instance.getToolDatabase(toolId);
    try {
      await _cachedDb!.migrate(
        currentVersion: 1,
        onMigrate: (txn, oldVersion, newVersion) async {
          if (oldVersion < 1) {
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(tableName)} (
                short_id TEXT PRIMARY KEY,
                file_name TEXT NOT NULL,
                file_data TEXT NOT NULL,
                mime_type TEXT NOT NULL,
                format TEXT NOT NULL,
                title TEXT NOT NULL,
                channels INTEGER NOT NULL,
                archived_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                deleted INTEGER NOT NULL DEFAULT 0,
                synced INTEGER NOT NULL DEFAULT 0
              )
            ''');
          }
        },
      );
    } catch (e) {
      debugPrint('[ChiptuneArchive] Migration failed: $e');
    }
    return _cachedDb!;
  }

  /// Content hash used as the stable, dedupe-friendly sync id (FNV-1a 64-bit).
  static String hashBytes(Uint8List data) {
    int hash = 0xcbf29ce484222325;
    const int prime = 0x100000001b3;
    const int mask = 0xFFFFFFFFFFFFFFFF;
    for (final b in data) {
      hash = (hash ^ b) & mask;
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  /// Lists non-deleted modules, newest first.
  Future<List<ArchivedModule>> getModules() async {
    final db = await _getDb();
    final rows = await db.query(
      tableName,
      columns: [
        'short_id',
        'file_name',
        'format',
        'title',
        'channels',
        'archived_at',
      ],
      where: 'deleted = 0',
      orderBy: 'archived_at DESC',
    );
    return rows
        .map(
          (r) => ArchivedModule(
            id: r['short_id'] as String,
            fileName: r['file_name'] as String,
            format: r['format'] as String,
            title: r['title'] as String,
            channels: r['channels'] as int,
            archivedAt: r['archived_at'] as int,
          ),
        )
        .toList();
  }

  Future<bool> exists(String id) async {
    final db = await _getDb();
    final rows = await db.query(
      tableName,
      columns: ['short_id'],
      where: 'short_id = ? AND deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Returns the raw module bytes for an archived id, or null if missing.
  Future<Uint8List?> getBytes(String id) async {
    final db = await _getDb();
    final rows = await db.query(
      tableName,
      columns: ['file_data'],
      where: 'short_id = ? AND deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return base64Decode(rows.first['file_data'] as String);
  }

  /// Archives a module. Returns false if an identical module already exists.
  Future<bool> saveModule({
    required Uint8List bytes,
    required String fileName,
    required String format,
    required String title,
    required int channels,
    String mimeType = 'application/octet-stream',
  }) async {
    final id = hashBytes(bytes);
    if (await exists(id)) return false;

    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(tableName, {
      'short_id': id,
      'file_name': fileName,
      'file_data': base64Encode(bytes),
      'mime_type': mimeType,
      'format': format,
      'title': title,
      'channels': channels,
      'archived_at': now,
      'updated_at': now,
      'deleted': 0,
      'synced': 0,
    });
    return true;
  }

  /// Soft-deletes a module (flagged for sync propagation).
  Future<void> deleteModule(String id) async {
    final db = await _getDb();
    await db.update(
      tableName,
      {
        'deleted': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'synced': 0,
      },
      where: 'short_id = ?',
      whereArgs: [id],
    );
  }

  // ---- Sync support ----

  Future<List<Map<String, dynamic>>> getSyncRecords() async {
    final db = await _getDb();
    return db.query(tableName, columns: ['short_id', 'updated_at', 'deleted']);
  }

  Future<Map<String, dynamic>?> getRecordData(String id) async {
    final db = await _getDb();
    final rows = await db.query(
      tableName,
      where: 'short_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty || (rows.first['deleted'] as int) == 1) return null;
    final r = rows.first;
    return {
      'fileName': r['file_name'],
      'fileData': r['file_data'],
      'mimeType': r['mime_type'],
      'format': r['format'],
      'title': r['title'],
      'channels': r['channels'],
      'archivedAt': r['archived_at'],
    };
  }

  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  }) async {
    final db = await _getDb();
    if (deleted) {
      await hardDelete(id);
      return;
    }
    final row = {
      'short_id': id,
      'file_name': data['fileName'] as String? ?? 'module',
      'file_data': data['fileData'] as String? ?? '',
      'mime_type': data['mimeType'] as String? ?? 'application/octet-stream',
      'format': data['format'] as String? ?? 'MOD',
      'title': data['title'] as String? ?? '',
      'channels': data['channels'] as int? ?? 4,
      'archived_at': data['archivedAt'] as int? ?? updatedAt,
      'updated_at': updatedAt,
      'deleted': 0,
      'synced': 1,
    };
    final existing = await db.query(
      tableName,
      columns: ['short_id'],
      where: 'short_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert(tableName, row);
    } else {
      await db.update(tableName, row, where: 'short_id = ?', whereArgs: [id]);
    }
  }

  Future<void> markSynced(String id) async {
    final db = await _getDb();
    await db.update(
      tableName,
      {'synced': 1},
      where: 'short_id = ?',
      whereArgs: [id],
    );
  }

  Future<void> hardDelete(String id) async {
    final db = await _getDb();
    await db.delete(tableName, where: 'short_id = ?', whereArgs: [id]);
  }
}
