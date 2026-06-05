class SharedFile {
  final String path;
  final String name;
  final String mimeType;

  const SharedFile({
    required this.path,
    required this.name,
    required this.mimeType,
  });

  factory SharedFile.fromMap(Map<dynamic, dynamic> map) {
    return SharedFile(
      path: map['path'] as String,
      name: map['name'] as String,
      mimeType: map['mimeType'] as String,
    );
  }

  Map<String, String> toMap() {
    return {'path': path, 'name': name, 'mimeType': mimeType};
  }
}
