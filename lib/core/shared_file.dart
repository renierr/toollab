import 'package:tool_lab/helpers/mime_type_helper.dart';

/// Describes where a downloaded copy of a [SharedFile] came from, so the
/// receiving tool can write changes back to the remote source.
class SharedFileOrigin {
  final String connectionId;
  final String protocol;
  final String host;
  final int port;
  final String share;
  final String username;
  final String remotePath;

  const SharedFileOrigin({
    required this.connectionId,
    required this.protocol,
    required this.host,
    required this.port,
    required this.share,
    required this.username,
    required this.remotePath,
  });

  factory SharedFileOrigin.fromMap(Map<dynamic, dynamic> map) {
    return SharedFileOrigin(
      connectionId: map['connectionId'] as String,
      protocol: map['protocol'] as String,
      host: map['host'] as String,
      port: map['port'] as int,
      share: map['share'] as String? ?? '',
      username: map['username'] as String? ?? '',
      remotePath: map['remotePath'] as String,
    );
  }

  Map<String, Object> toMap() => {
    'connectionId': connectionId,
    'protocol': protocol,
    'host': host,
    'port': port,
    'share': share,
    'username': username,
    'remotePath': remotePath,
  };
}

class SharedFile {
  final String path;
  final String name;
  final String mimeType;
  final SharedFileOrigin? origin;

  /// Android: a streamable `content://` URI that was not copied; [path] is
  /// empty until [SharingService.materialize] copies it.
  final String? contentUri;

  SharedFile({
    required this.path,
    required this.name,
    required String mimeType,
    this.origin,
    this.contentUri,
  }) : mimeType = _resolveMimeType(path, name, mimeType);

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
      origin: map['origin'] is Map
          ? SharedFileOrigin.fromMap(map['origin'])
          : null,
      contentUri: map['contentUri'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'path': path,
    'name': name,
    'mimeType': mimeType,
    if (origin != null) 'origin': origin!.toMap(),
    if (contentUri != null) 'contentUri': contentUri,
  };

  bool get needsCopy => path.isEmpty && contentUri != null;

  /// Where the content lives, for playback and duplicate checks.
  Uri get uri => contentUri != null ? Uri.parse(contentUri!) : Uri.file(path);
}

class SharedData {
  final List<SharedFile> files;
  final String? text;

  SharedData(this.files, {this.text});

  factory SharedData.single(SharedFile file) => SharedData([file]);
  factory SharedData.text(String text) => SharedData([], text: text);

  bool get isMultiple => files.length > 1;
  bool get isEmpty => files.isEmpty && text == null;

  SharedFile? get firstFile => files.isNotEmpty ? files.first : null;
}
