import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'signature_models.dart';

/// Local persistence for saved signatures.
///
/// The PNG preview is stored as a native `BLOB`; stroke geometry and settings
/// are stored as JSON `TEXT`. The on-the-wire format (see [getRecordDataForSync])
/// matches the browser-toolkit `SignatureData` shape for bidirectional sync.
class SignaturesDbHelper {
  static const String tableName = 'records';

  SignaturesDbHelper._privateConstructor();
  static final SignaturesDbHelper instance =
      SignaturesDbHelper._privateConstructor();

  ToolDatabase? _cachedDb;

  Future<ToolDatabase> _getDb() async {
    if (_cachedDb != null) return _cachedDb!;
    _cachedDb = await DatabaseService.instance.getToolDatabase(
      SignaturesTool.config.id,
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
                image BLOB,
                width REAL NOT NULL,
                height REAL NOT NULL,
                raw_paths TEXT NOT NULL,
                settings TEXT NOT NULL,
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
      debugPrint('[SignaturesDbHelper] Migration failed: $e');
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

  static Uint8List? _imageFromRow(dynamic raw) {
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    return null;
  }

  static String _encodePaths(List<List<SignaturePoint>> paths) {
    return jsonEncode(
      paths.map((s) => s.map((p) => p.toJson()).toList()).toList(),
    );
  }

  static List<List<SignaturePoint>> _decodePaths(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final decoded = jsonDecode(json) as List<dynamic>;
      return decoded
          .map<List<SignaturePoint>>(
            (stroke) => (stroke as List<dynamic>)
                .map(
                  (p) => SignaturePoint.fromJson(
                    Map<String, dynamic>.from(p as Map),
                  ),
                )
                .toList(),
          )
          .toList();
    } catch (e) {
      debugPrint('[SignaturesDbHelper] Failed to decode paths: $e');
      return [];
    }
  }

  static SignatureSettings _decodeSettings(String? json) {
    if (json == null || json.isEmpty) return SignatureSettings.defaults;
    try {
      return SignatureSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(json) as Map),
      );
    } catch (_) {
      return SignatureSettings.defaults;
    }
  }

  SignatureRecord _recordFromRow(Map<String, Object?> r) {
    return SignatureRecord(
      shortId: r['short_id'] as String,
      image: _imageFromRow(r['image']),
      width: (r['width'] as num).toDouble(),
      height: (r['height'] as num).toDouble(),
      rawPaths: _decodePaths(r['raw_paths'] as String?),
      settings: _decodeSettings(r['settings'] as String?),
      createdAt: r['created_at'] as int? ?? 0,
      updatedAt: r['updated_at'] as int? ?? 0,
    );
  }

  /// All active (non-deleted) signatures, newest first.
  Future<List<SignatureRecord>> getActiveRecords() async {
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

  /// Inserts or updates a signature, bumping `updated_at` and clearing `synced`.
  Future<void> saveRecord({
    required String shortId,
    required Uint8List image,
    required double width,
    required double height,
    required List<List<SignaturePoint>> rawPaths,
    required SignatureSettings settings,
  }) async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _rowByShortId(shortId);

    final values = <String, Object?>{
      'short_id': shortId,
      'image': image,
      'width': width,
      'height': height,
      'raw_paths': _encodePaths(rawPaths),
      'settings': jsonEncode(settings.toJson()),
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

  /// Soft-delete (flagged for sync, removed locally on finalize).
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

  /// Wire payload for the browser-toolkit backend. `image` is emitted as a
  /// plain base64 data-URL string (not a `__type:'blob'` wrapper) to match the
  /// existing record format on the server.
  Future<Map<String, dynamic>?> getRecordDataForSync(String shortId) async {
    final row = await _rowByShortId(shortId);
    if (row == null || (row['deleted'] as int? ?? 0) == 1) return null;
    final image = _imageFromRow(row['image']);
    final imageData = image != null && image.isNotEmpty
        ? base64Encode(image)
        : '';
    final imageUri = imageData.isNotEmpty
        ? 'data:image/png;base64,$imageData'
        : '';
    return {
      'id': shortId,
      'image': imageUri,
      'imageBlob': {
        '__type': 'blob',
        'mimeType': 'image/png',
        'data': imageData,
      },
      'width': (row['width'] as num).toDouble(),
      'height': (row['height'] as num).toDouble(),
      'timestamp': row['created_at'],
      'updatedAt': row['updated_at'],
      'settings': _decodeSettings(row['settings'] as String?).toJson(),
      'rawPaths': jsonDecode(row['raw_paths'] as String? ?? '[]'),
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

    final image = _decodeImageField(data['image']);
    final rawPaths = data['rawPaths'];
    final settings = data['settings'];

    final values = <String, Object?>{
      'short_id': id,
      'image': image,
      'width': (data['width'] as num?)?.toDouble() ?? 1.0,
      'height': (data['height'] as num?)?.toDouble() ?? 1.0,
      'raw_paths': rawPaths == null ? '[]' : jsonEncode(rawPaths),
      'settings': settings == null
          ? jsonEncode(SignatureSettings.defaults.toJson())
          : jsonEncode(settings),
      'created_at': (data['timestamp'] as num?)?.toInt() ?? updatedAt,
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

  /// Decodes the `image` wire field (a `data:...;base64,xxx` URL or bare base64).
  static Uint8List? _decodeImageField(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    var b64 = raw;
    final comma = raw.indexOf(',');
    if (raw.startsWith('data:') && comma != -1) {
      b64 = raw.substring(comma + 1);
    }
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }
}
