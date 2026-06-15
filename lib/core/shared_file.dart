import 'package:tool_lab/helpers/mime_type_helper.dart';

class SharedFile {
  final String path;
  final String name;
  final String mimeType;

  SharedFile({required this.path, required this.name, required String mimeType})
    : mimeType = _resolveMimeType(path, name, mimeType);

  static String _resolveMimeType(String path, String name, String mimeType) {
    if (mimeType.toLowerCase() == 'application/octet-stream') {
      final resolved = MimeTypeHelper.getMimeType(
        path.isNotEmpty ? path : name,
      );
      if (resolved != 'application/octet-stream') {
        return resolved;
      }
    }
    return mimeType;
  }

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

class SharedData {
  final List<SharedFile> files;

  SharedData(this.files);

  factory SharedData.single(SharedFile file) => SharedData([file]);

  bool get isMultiple => files.length > 1;
  bool get isEmpty => files.isEmpty;

  SharedFile? get firstFile => files.isNotEmpty ? files.first : null;
}
