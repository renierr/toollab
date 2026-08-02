import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:tool_lab/tools/file_manager/archives/archive_handler.dart';

class ZipArchiveHandler implements ArchiveHandler {
  const ZipArchiveHandler();

  @override
  bool supports(String path) => path.toLowerCase().endsWith('.zip');

  @override
  Future<void> create({
    required List<String> sourcePaths,
    required String destinationPath,
  }) async {
    final encoder = ZipFileEncoder();
    encoder.create(destinationPath);
    try {
      for (final sourcePath in sourcePaths) {
        final entity = FileSystemEntity.typeSync(sourcePath);
        if (entity == FileSystemEntityType.directory) {
          await encoder.addDirectory(Directory(sourcePath));
        } else if (entity == FileSystemEntityType.file) {
          await encoder.addFile(File(sourcePath));
        }
      }
    } finally {
      await encoder.close();
    }
  }

  @override
  Future<void> extract({
    required String archivePath,
    required String destinationPath,
    required Future<ArchiveConflictResolution> Function(String path) onConflict,
  }) async {
    final input = InputFileStream(archivePath);
    final archive = ZipDecoder().decodeStream(input);
    final destination = p.normalize(destinationPath);
    for (final entry in archive) {
      final outputPath = p.normalize(p.join(destination, entry.name));
      if (!p.isWithin(destination, outputPath) && outputPath != destination) {
        continue;
      }
      if (entry.isFile) {
        var resolvedPath = outputPath;
        final output = File(resolvedPath);
        if (await output.exists()) {
          final resolution = await onConflict(resolvedPath);
          if (resolution == ArchiveConflictResolution.skip) continue;
          if (resolution == ArchiveConflictResolution.keepBoth) {
            resolvedPath = uniqueArchivePath(resolvedPath);
          }
        }
        final target = File(resolvedPath);
        await target.parent.create(recursive: true);
        await target.writeAsBytes(entry.content as List<int>);
      } else {
        await Directory(outputPath).create(recursive: true);
      }
    }
  }
}
