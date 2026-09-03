import '../../services/database_service.dart';
import 'config.dart';
import 'engine/voice_effect.dart';

class VoicePresetsDbHelper {
  static const String tableName = 'voice_presets';

  VoicePresetsDbHelper._privateConstructor();
  static final VoicePresetsDbHelper instance =
      VoicePresetsDbHelper._privateConstructor();

  ToolDatabase? _cachedDb;

  Future<ToolDatabase> _getDb() async {
    if (_cachedDb != null) return _cachedDb!;
    _cachedDb = await DatabaseService.instance.getToolDatabase(
      VoiceDistorterTool.config.id,
    );
    await _cachedDb!.migrate(
      currentVersion: 2,
      onMigrate: (txn, oldVersion, newVersion) async {
        if (oldVersion < 1) {
          await txn.execute('''
            CREATE TABLE ${txn.nameTable(tableName)} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              pitch REAL NOT NULL DEFAULT 0,
              robot REAL NOT NULL DEFAULT 0,
              echo REAL NOT NULL DEFAULT 0,
              reverb REAL NOT NULL DEFAULT 0,
              lofi REAL NOT NULL DEFAULT 0,
              distortion REAL NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 2) {
          await txn.execute(
            'ALTER TABLE ${txn.nameTable(tableName)} '
            'ADD COLUMN formant REAL NOT NULL DEFAULT 0',
          );
        }
      },
    );
    return _cachedDb!;
  }

  VoicePreset _fromMap(Map<String, Object?> map) {
    final int id = map['id'] as int;
    return VoicePreset(
      dbId: id,
      id: 'custom_$id',
      name: map['name'] as String? ?? '',
      params: VoiceEffectParams(
        pitchSemitones: (map['pitch'] as num?)?.toDouble() ?? 0,
        formantSemitones: (map['formant'] as num?)?.toDouble() ?? 0,
        robotAmount: (map['robot'] as num?)?.toDouble() ?? 0,
        echoAmount: (map['echo'] as num?)?.toDouble() ?? 0,
        reverbAmount: (map['reverb'] as num?)?.toDouble() ?? 0,
        lofiAmount: (map['lofi'] as num?)?.toDouble() ?? 0,
        distortionAmount: (map['distortion'] as num?)?.toDouble() ?? 0,
      ),
    );
  }

  Future<List<VoicePreset>> list() async {
    final db = await _getDb();
    final rows = await db.query(tableName, orderBy: 'created_at ASC');
    return rows.map(_fromMap).toList();
  }

  Future<VoicePreset> save(String name, VoiceEffectParams params) async {
    final db = await _getDb();
    final int id = await db.insert(tableName, {
      'name': name,
      'pitch': params.pitchSemitones,
      'formant': params.formantSemitones,
      'robot': params.robotAmount,
      'echo': params.echoAmount,
      'reverb': params.reverbAmount,
      'lofi': params.lofiAmount,
      'distortion': params.distortionAmount,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return VoicePreset(dbId: id, id: 'custom_$id', name: name, params: params);
  }

  Future<void> delete(int dbId) async {
    final db = await _getDb();
    await db.delete(tableName, where: 'id = ?', whereArgs: [dbId]);
  }
}
