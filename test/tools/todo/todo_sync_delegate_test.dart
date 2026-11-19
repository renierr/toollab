import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/todo/models/todo_list.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_db_helper.dart';
import 'package:tool_lab/tools/todo/todo_recurrence.dart';
import 'package:tool_lab/tools/todo/todo_sync_delegate.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  final db = TodoDbHelper.instance;
  final delegate = TodoSyncDelegate();

  test('ids carry the record kind', () {
    expect(TodoSyncDelegate.recordId(TodoRecordKind.task, 'ABC'), 't_ABC');
    expect(TodoSyncDelegate.parseId('a_XYZ'), (
      TodoRecordKind.attachment,
      'XYZ',
    ));
    expect(TodoSyncDelegate.parseId('zzz'), isNull);
  });

  test('task round-trips through push and pull payloads', () async {
    final task = TodoTask(
      shortId: 'TASK1',
      listId: 'LIST1',
      title: 'Taxes',
      note: 'Bring receipts',
      important: true,
      dueAt: DateTime(2027, 5, 31).millisecondsSinceEpoch,
      recurrence: TodoRecurrence.yearly,
      sortOrder: 2,
      steps: const [TodoStep(id: 's1', title: 'Collect', done: true)],
      reminders: const [TodoReminder(at: 123, alarm: true)],
      tags: const ['finance'],
      createdAt: 10,
      updatedAt: 20,
    );
    await db.upsertTask(task);
    final payload = (await delegate.getLocalRecordData('t_TASK1'))!;
    await delegate.savePulledRecord(
      id: 't_TASK2',
      data: jsonDecode(jsonEncode(payload)) as Map<String, dynamic>,
      updatedAt: 30,
      deleted: false,
    );
    final copy = (await db.getTask('TASK2'))!;
    expect(copy.title, 'Taxes');
    expect(copy.important, isTrue);
    expect(copy.recurrence, TodoRecurrence.yearly);
    expect(copy.steps.single.done, isTrue);
    expect(copy.reminders.single.alarm, isTrue);
    expect(copy.tags, ['finance']);
    expect(copy.updatedAt, 30);
  });

  test('attachment blobs use the wire format and come back', () async {
    final bytes = Uint8List.fromList(List.generate(64, (i) => i));
    await db.insertAttachment(
      shortId: 'ATT1',
      taskId: 'TASK1',
      name: 'scan.bin',
      mimeType: 'application/octet-stream',
      data: bytes,
      createdAt: 1,
      updatedAt: 1,
    );
    final payload = (await delegate.getLocalRecordData('a_ATT1'))!;
    final blob = payload['data'] as Map<String, dynamic>;
    expect(blob['__type'], 'blob');
    // SyncService unwraps blobs to their base64 string before saving.
    await delegate.savePulledRecord(
      id: 'a_ATT2',
      data: {...payload, 'data': blob['data']},
      updatedAt: 5,
      deleted: false,
    );
    expect(await db.getAttachmentData('ATT2'), bytes);
  });

  test('deletes tombstone, then finalize removes the row', () async {
    await db.upsertList(
      const TodoList(
        shortId: 'L9',
        name: 'Temp',
        color: 0,
        sortOrder: 0,
        createdAt: 0,
        updatedAt: 0,
      ),
    );
    await db.softDelete(TodoRecordKind.list, 'L9');
    final records = await delegate.getLocalSyncRecords();
    expect(records.firstWhere((r) => r['id'] == 'l_L9')['deleted'], isTrue);
    await delegate.finalizeLocalSync('l_L9', true);
    expect(await db.getList('L9'), isNull);
  });
}
