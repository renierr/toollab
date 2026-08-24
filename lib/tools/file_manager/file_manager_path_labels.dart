/// Well-known folder names and how they are labelled in the UI.
const Map<String, String> fileManagerFolderLabels = {
  'download': 'Downloads',
  'downloads': 'Downloads',
  'documents': 'Documents',
  'images': 'Images',
  'pictures': 'Images',
  'music': 'Music',
  'videos': 'Videos',
  'movies': 'Videos',
  'dcim': 'DCIM',
};

/// Shortens a folder path for display: the part up to a well-known folder is
/// noise the user already knows (`/storage/emulated/0`, `C:\Users\<name>`), so
/// the label starts at that folder and keeps everything below it.
String fileManagerFolderLabel(String path) {
  final parts = path
      .replaceAll(r'\', '/')
      .split('/')
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '/';
  for (var index = 0; index < parts.length; index++) {
    final label = fileManagerFolderLabels[parts[index].toLowerCase()];
    if (label != null) return [label, ...parts.skip(index + 1)].join('/');
  }
  final trimmed = _stripHomePrefix(parts);
  return trimmed.isEmpty ? parts.last : trimmed.join('/');
}

List<String> _stripHomePrefix(List<String> parts) {
  if (parts.length > 3 &&
      parts[0].toLowerCase() == 'storage' &&
      parts[1].toLowerCase() == 'emulated') {
    return parts.sublist(3);
  }
  if (parts.length > 3 &&
      (parts[1].toLowerCase() == 'users' || parts[1].toLowerCase() == 'home')) {
    return parts.sublist(3);
  }
  if (parts.length > 2 && parts[0].toLowerCase() == 'home') {
    return parts.sublist(2);
  }
  return parts;
}
