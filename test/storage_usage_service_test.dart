import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/services/storage_usage_service.dart';

void main() {
  test('children measures folders recursively, largest first', () async {
    final dir = await Directory.systemTemp.createTemp('storage_usage_test');
    addTearDown(() => dir.delete(recursive: true));
    File('${dir.path}/small.txt').writeAsBytesSync(List.filled(10, 0));
    Directory('${dir.path}/big/nested').createSync(recursive: true);
    File('${dir.path}/big/a.bin').writeAsBytesSync(List.filled(100, 0));
    File('${dir.path}/big/nested/b.bin').writeAsBytesSync(List.filled(50, 0));

    final entries = await StorageUsageService.children(dir.path);

    expect(entries.map((e) => e.name), ['big', 'small.txt']);
    expect(entries.first.bytes, 150);
    expect(entries.first.fileCount, 2);
    expect(entries.first.isDirectory, isTrue);
    expect(entries.last.bytes, 10);
  });
}
