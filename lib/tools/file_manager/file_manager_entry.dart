class FileManagerEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final int? size;
  final DateTime? modified;
  final String? archivePath;
  final String? archiveEntryPath;

  /// A symlink or Windows junction whose target no longer exists, so it can
  /// neither be followed nor read.
  final bool isBrokenLink;

  const FileManagerEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.modified,
    this.archivePath,
    this.archiveEntryPath,
    this.isBrokenLink = false,
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
        isBrokenLink: isBrokenLink,
      );
}
