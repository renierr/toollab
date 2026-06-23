import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'models/drawing_record.dart';
import 'models/sketch_element.dart';

/// Local persistence for saved drawings.
///
/// The thumbnail is stored as a native `BLOB`; elements / viewport / meta are
/// JSON `TEXT`. The sync wire format (see [getRecordDataForSync]) matches the
/// browser-toolkit `DrawingRecord` shape for bidirectional sync.
class SketchBoardDbHelper {
  static const String tableName = 'drawings';

  SketchBoardDbHelper._privateConstructor();
  static final SketchBoardDbHelper instance =
      SketchBoardDbHelper._privateConstructor();

  ToolDatabase? _cachedDb;

  Future<ToolDatabase> _getDb() async {
    if (_cachedDb != null) return _cachedDb!;
    _cachedDb = await DatabaseService.instance.getToolDatabase(
      SketchBoardTool.config.id,
    );
    try {
      await _cachedDb!.migrate(
        currentVersion: 1,
        onMigrate: (txn, oldVersion, newVersion) async {
          if (oldVersion < 1) {
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(tableName)} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                short_id TEXT NOT NULL UNIQUE,
                name TEXT NOT NULL,
                viewport TEXT NOT NULL,
                elements TEXT NOT NULL,
                thumbnail BLOB,
                meta TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                deleted INTEGER NOT NULL DEFAULT 0,
                synced INTEGER NOT NULL DEFAULT 0
              )
            ''');
          }
        },
      );
    } catch (e) {
      debugPrint('[SketchBoardDbHelper] Migration failed: $e');
    }
    return _cachedDb!;
  }

  /// RFC-4122 v4 UUID (matches the browser-toolkit `crypto.randomUUID()` ids).
  String generateUuid() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  static Uint8List? _blobFromRow(dynamic raw) {
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        return base64Decode(raw);
      } catch (_) {}
    }
    return null;
  }

  static List<SketchElement> _decodeElements(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final decoded = jsonDecode(json) as List<dynamic>;
      return decoded
          .map(
            (e) => SketchElement.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      debugPrint('[SketchBoardDbHelper] Failed to decode elements: $e');
      return [];
    }
  }

  static String _encodeElements(List<SketchElement> els) =>
      jsonEncode(els.map((e) => e.toJson()).toList());

  static ViewportState _decodeViewport(String? json) {
    if (json == null || json.isEmpty) return const ViewportState();
    try {
      return ViewportState.fromJson(
        Map<String, dynamic>.from(jsonDecode(json) as Map),
      );
    } catch (_) {
      return const ViewportState();
    }
  }

  static DrawingMeta _decodeMeta(String? json) {
    if (json == null || json.isEmpty) {
      return const DrawingMeta(elementCount: 0, colors: [], lastTool: 'pan');
    }
    try {
      return DrawingMeta.fromJson(
        Map<String, dynamic>.from(jsonDecode(json) as Map),
      );
    } catch (_) {
      return const DrawingMeta(elementCount: 0, colors: [], lastTool: 'pan');
    }
  }

  DrawingRecord _recordFromRow(Map<String, Object?> r) => DrawingRecord(
    shortId: r['short_id'] as String,
    name: (r['name'] as String?) ?? '',
    viewport: _decodeViewport(r['viewport'] as String?),
    elements: _decodeElements(r['elements'] as String?),
    thumbnail: _blobFromRow(r['thumbnail']),
    meta: _decodeMeta(r['meta'] as String?),
    createdAt: r['created_at'] as int? ?? 0,
    updatedAt: r['updated_at'] as int? ?? 0,
  );

  /// All active (non-deleted) drawings, newest first.
  Future<List<DrawingRecord>> getActiveRecords() async {
    final db = await _getDb();
    final rows = await db.query(
      tableName,
      where: 'deleted = 0',
      orderBy: 'updated_at DESC',
    );
    return rows.map(_recordFromRow).toList();
  }

  Future<Map<String, Object?>?> _rowByShortId(String shortId) async {
    final db = await _getDb();
    final rows = await db.query(
      tableName,
      where: 'short_id = ?',
      whereArgs: [shortId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Inserts or updates a drawing, bumping `updated_at` and clearing `synced`.
  Future<void> saveRecord({
    required String shortId,
    required String name,
    required ViewportState viewport,
    required List<SketchElement> elements,
    required Uint8List thumbnail,
    required DrawingMeta meta,
  }) async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _rowByShortId(shortId);

    final values = <String, Object?>{
      'short_id': shortId,
      'name': name,
      'viewport': jsonEncode(viewport.toJson()),
      'elements': _encodeElements(elements),
      'thumbnail': thumbnail,
      'meta': jsonEncode(meta.toJson()),
      'updated_at': existing == null
          ? now
          : max(now, (existing['updated_at'] as int? ?? 0) + 1),
      'deleted': 0,
      'synced': 0,
    };

    if (existing == null) {
      values['created_at'] = now;
      await db.insert(tableName, values);
    } else {
      await db.update(
        tableName,
        values,
        where: 'short_id = ?',
        whereArgs: [shortId],
      );
    }
  }

  Future<void> softDelete(String shortId) async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _rowByShortId(shortId);
    final updatedAt = max(now, (existing?['updated_at'] as int? ?? 0) + 1);
    await db.update(
      tableName,
      {'deleted': 1, 'updated_at': updatedAt, 'synced': 0},
      where: 'short_id = ?',
      whereArgs: [shortId],
    );
  }

  Future<void> hardDelete(String shortId) async {
    final db = await _getDb();
    await db.delete(tableName, where: 'short_id = ?', whereArgs: [shortId]);
  }

  Future<void> markSynced(String shortId) async {
    final db = await _getDb();
    await db.update(
      tableName,
      {'synced': 1},
      where: 'short_id = ?',
      whereArgs: [shortId],
    );
  }

  // ---- Sync ----

  Future<List<Map<String, dynamic>>> getSyncRecords() async {
    final db = await _getDb();
    return await db.query(
      tableName,
      columns: ['short_id', 'updated_at', 'deleted'],
    );
  }

  /// Wire payload mirroring the browser-toolkit `DrawingRecord`. The thumbnail
  /// BLOB is emitted as an inline `data:image/png;base64,...` string (not a
  /// `__type:'blob'` wrapper) to match the existing record format on the server.
  Future<Map<String, dynamic>?> getRecordDataForSync(String shortId) async {
    final row = await _rowByShortId(shortId);
    if (row == null || (row['deleted'] as int? ?? 0) == 1) return null;
    final thumb = _blobFromRow(row['thumbnail']);
    final thumbUrl = thumb != null && thumb.isNotEmpty
        ? 'data:image/png;base64,${base64Encode(thumb)}'
        : '';
    return {
      'id': shortId,
      'name': (row['name'] as String?) ?? '',
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
      'viewport': jsonDecode(row['viewport'] as String? ?? '{}'),
      'elements': jsonDecode(row['elements'] as String? ?? '[]'),
      'thumbnailDataUrl': thumbUrl,
      'meta': jsonDecode(row['meta'] as String? ?? '{}'),
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

    final thumbnail = _decodeDataUrl(data['thumbnailDataUrl']);
    final values = <String, Object?>{
      'short_id': id,
      'name': (data['name'] as String?) ?? '',
      'viewport': jsonEncode(data['viewport'] ?? const {}),
      'elements': jsonEncode(data['elements'] ?? const []),
      'thumbnail': thumbnail,
      'meta': jsonEncode(data['meta'] ?? const {}),
      'created_at': (data['createdAt'] as num?)?.toInt() ?? updatedAt,
      'updated_at': updatedAt,
      'deleted': 0,
      'synced': 1,
    };

    final existing = await _rowByShortId(id);
    if (existing == null) {
      await db.insert(tableName, values);
    } else {
      await db.update(
        tableName,
        values,
        where: 'short_id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Decodes a `data:...;base64,xxx` URL (or bare base64) into raw bytes.
  static Uint8List? _decodeDataUrl(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    var b64 = raw;
    final comma = raw.indexOf(',');
    if (raw.startsWith('data:') && comma != -1) b64 = raw.substring(comma + 1);
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }
}
