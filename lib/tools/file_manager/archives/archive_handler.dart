import 'dart:io';

enum ArchiveConflictResolution { overwrite, keepBoth, skip }

abstract interface class ArchiveHandler {
  bool supports(String path);

  Future<List<ArchiveEntry>> listEntries({
    required String archivePath,
    required String directoryPath,
  });

  Future<void> extractEntry({
    required String archivePath,
    required String entryPath,
    required String destinationPath,
  });

  Future<void> extract({
    required String archivePath,
    required String destinationPath,
    required Future<ArchiveConflictResolution> Function(String path) onConflict,
  });

  Future<void> create({
    required List<String> sourcePaths,
    required String destinationPath,
  });
}

class ArchiveEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final int? size;
  final DateTime? modified;

  const ArchiveEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.modified,
  });
}

String uniqueArchivePath(String path) {
  final file = File(path);
  if (!file.existsSync()) return path;
  final dot = path.lastIndexOf('.');
  final base = dot > 0 ? path.substring(0, dot) : path;
  final extension = dot > 0 ? path.substring(dot) : '';
  for (var index = 1; ; index++) {
    final candidate = '$base ($index)$extension';
    if (!File(candidate).existsSync()) return candidate;
  }
}
