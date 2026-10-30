import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:tool_lab/helpers/temp_file_manager.dart';

import 'depot_store.dart';

/// Packs every Depot table into a ZIP, as one CSV each plus a standalone
/// SQLite database, readable without the app.
class DepotDataExport {
  DepotDataExport._();

  /// Stored as epoch milliseconds; exported as ISO 8601 UTC.
  static const _dateColumns = {
    'created_at',
    'added_at',
    'updated_at',
    'datetime',
    'date',
    'synced_at',
    'quote_at',
    'earliest_activity',
    'fetched_at',
    'attempted_at',
    'ex_date',
    'next_ex_date',
    'next_pay_date',
  };

  static const sqliteName = 'depot.sqlite';

  /// The SQLite copy is built in [scope], which owns the temp file.
  static Future<Uint8List> zip(TempFileScope scope) async {
    final tables = await DepotStore.instance.dumpTables();
    final archive = Archive()
      ..addFile(ArchiveFile.bytes(sqliteName, await _sqlite(tables, scope)));
    for (final table in tables) {
      archive.addFile(
        ArchiveFile.bytes('${table.name}.csv', utf8.encode(csv(table))),
      );
    }
    return ZipEncoder().encodeBytes(archive);
  }

  /// Same schema and raw values as the app, under plain table names.
  static Future<Uint8List> _sqlite(
    List<DepotTableDump> tables,
    TempFileScope scope,
  ) async {
    await scope.deleteFile(sqliteName);
    final path = await scope.createFile(sqliteName);
    final db = await databaseFactory.openDatabase(path);
    try {
      await db.transaction((txn) async {
        for (final table in tables) {
          await txn.execute(table.createSql);
          final batch = txn.batch();
          for (final row in table.rows) {
            batch.insert(table.name, {
              for (var i = 0; i < row.length; i++) table.columns[i]: row[i],
            });
          }
          await batch.commit(noResult: true);
        }
      });
    } finally {
      await db.close();
    }
    return scope.readFile(sqliteName);
  }

  /// RFC 4180 with a BOM, so spreadsheet apps detect UTF-8. Binary columns
  /// are left out.
  static String csv(DepotTableDump table) {
    final kept = [
      for (var i = 0; i < table.columns.length; i++)
        if (!table.binaryColumns.contains(table.columns[i])) i,
    ];
    final out = StringBuffer(String.fromCharCode(0xFEFF))
      ..write(kept.map((i) => _quote(table.columns[i])).join(','))
      ..write('\r\n');
    for (final row in table.rows) {
      final cells = [
        for (final i in kept) _quote(_cell(table.columns[i], row[i])),
      ];
      out
        ..write(cells.join(','))
        ..write('\r\n');
    }
    return out.toString();
  }

  static String _cell(String column, Object? value) => switch (value) {
    null => '',
    final int ms when _dateColumns.contains(column) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String(),
    _ => '$value',
  };

  static String _quote(String value) => value.contains(RegExp(r'[",\r\n]'))
      ? '"${value.replaceAll('"', '""')}"'
      : value;
}
