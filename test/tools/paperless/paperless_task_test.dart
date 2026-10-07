import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/paperless/models/paperless_task.dart';

void main() {
  test('v9 duplicate failure keeps reason and id', () {
    final task = PaperlessTask.fromJson({
      'status': 'FAILURE',
      'result':
          'scan.pdf: Not consuming scan.pdf: It is a duplicate of bill (#1884).',
      'related_document': null,
    });
    expect(task.status, PaperlessTaskStatus.failure);
    expect(task.result, contains('duplicate of bill (#1884)'));
    expect(task.duplicateDocumentId, 1884);
    expect(task.isDuplicate, isTrue);
  });

  test('v10 failure reads result_message and duplicate_of', () {
    final task = PaperlessTask.fromJson({
      'status': 'failure',
      'result_message': 'Not consuming scan.pdf: It is a duplicate.',
      'result_data': {'duplicate_of': 42},
      'related_document_ids': [],
    });
    expect(task.status, PaperlessTaskStatus.failure);
    expect(task.result, contains('duplicate'));
    expect(task.duplicateDocumentId, 42);
    expect(task.documentId, 42);
    expect(task.isDuplicate, isTrue);
  });

  test('v10 structured error_message is surfaced', () {
    final task = PaperlessTask.fromJson({
      'status': 'FAILURE',
      'result_data': {'error_message': 'File is corrupt'},
      'related_document_ids': [],
    });
    expect(task.result, 'File is corrupt');
    expect(task.isDuplicate, isFalse);
  });

  test('success keeps created document id', () {
    final task = PaperlessTask.fromJson({
      'status': 'SUCCESS',
      'result': 'Success. New document id 416 created',
      'related_document': '416',
    });
    expect(task.status, PaperlessTaskStatus.success);
    expect(task.documentId, 416);
    expect(task.isDuplicate, isFalse);
  });
}
