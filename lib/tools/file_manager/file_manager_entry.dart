class FileManagerEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final int? size;
  final DateTime? modified;
  final String? archivePath;
  final String? archiveEntryPath;

  const FileManagerEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.modified,
    this.archivePath,
    this.archiveEntryPath,
  });

  bool get isArchiveEntry => archivePath != null && archiveEntryPath != null;

  FileManagerEntry copyWith({int? size, DateTime? modified}) =>
      FileManagerEntry(
        name: name,
        path: path,
        isDirectory: isDirectory,
        size: size ?? this.size,
        modified: modified ?? this.modified,
        archivePath: archivePath,
        archiveEntryPath: archiveEntryPath,
      );
}
