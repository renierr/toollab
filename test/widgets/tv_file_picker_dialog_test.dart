import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tv_file_picker_dialog.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tv_picker_test_');
    await Directory(p.join(tempDir.path, 'Subfolder')).create();
    await File(p.join(tempDir.path, 'song.mod')).writeAsString('mod');
    await File(p.join(tempDir.path, 'notes.txt')).writeAsString('txt');
    await File(p.join(tempDir.path, 'Subfolder', 'nested.xm')).writeAsString(
      'xm',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('filters by extension and selects a file via D-pad/OK', (
    tester,
  ) async {
    List<String>? pickedPaths;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final files = await showDialog<List<XFile>>(
                  context: context,
                  builder: (_) => TvFilePickerDialog(
                    initialPath: tempDir.path,
                    allowedExtensions: const ['mod', 'xm'],
                  ),
                );
                pickedPaths = files?.map((f) => f.path).toList();
              },
              child: const Text('Pick'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();

    expect(find.text('Subfolder'), findsOneWidget);
    expect(find.text('song.mod'), findsOneWidget);
    expect(find.text('notes.txt'), findsNothing);

    await tester.tap(find.text('song.mod'));
    await tester.pumpAndSettle();

    expect(pickedPaths, [p.join(tempDir.path, 'song.mod')]);
  });

  testWidgets('navigates into subfolder and supports multiple selection', (
    tester,
  ) async {
    List<String>? pickedPaths;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final files = await showDialog<List<XFile>>(
                  context: context,
                  builder: (_) => TvFilePickerDialog(
                    initialPath: tempDir.path,
                    allowedExtensions: const ['mod', 'xm'],
                    allowMultiple: true,
                  ),
                );
                pickedPaths = files?.map((f) => f.path).toList();
              },
              child: const Text('Pick'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('song.mod'));
    await tester.pump();
    await tester.tap(find.text('Subfolder'));
    await tester.pumpAndSettle();

    expect(find.text('nested.xm'), findsOneWidget);
    await tester.tap(find.text('nested.xm'));
    await tester.pump();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(pickedPaths, [
      p.join(tempDir.path, 'song.mod'),
      p.join(tempDir.path, 'Subfolder', 'nested.xm'),
    ]);
  });
}
