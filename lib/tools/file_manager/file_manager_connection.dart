enum FileManagerProtocol { ftp, smb }

class FileManagerConnection {
  final String id;
  final String label;
  final FileManagerProtocol protocol;
  final String host;
  final int port;
  final String share;
  final String username;
  final String initialPath;

  const FileManagerConnection({
    required this.id,
    required this.label,
    required this.protocol,
    required this.host,
    required this.port,
    required this.share,
    required this.username,
    required this.initialPath,
  });

  Map<String, Object> toJson() => {
    'id': id,
    'label': label,
    'protocol': protocol.name,
    'host': host,
    'port': port,
    'share': share,
    'username': username,
    'initialPath': initialPath,
  };

  factory FileManagerConnection.fromJson(Map<String, dynamic> json) =>
      FileManagerConnection(
        id: json['id'] as String,
        label: json['label'] as String,
        protocol: FileManagerProtocol.values.byName(json['protocol'] as String),
        host: json['host'] as String,
        port: json['port'] as int,
        share: json['share'] as String? ?? '',
        username: json['username'] as String? ?? '',
        initialPath: json['initialPath'] as String? ?? '',
      );
}
