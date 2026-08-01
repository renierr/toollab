import 'dart:convert';
import 'dart:io';

import 'package:dart_smb2/dart_smb2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/file_manager/config.dart';
import 'package:tool_lab/tools/file_manager/file_manager_connection.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';
import 'package:tool_lab/tools/file_manager/file_manager_storage_access.dart';

enum FileManagerLocationType { local, ftp, smb }

class FileManagerState extends ChangeNotifier {
  static const _connectionsKey = 'connections';
  static const _favoritesKey = 'favorite_paths';
  static const _secureStorage = FlutterSecureStorage();

  List<FileManagerEntry> _entries = [];
  List<FileManagerConnection> _connections = [];
  List<String> _favoritePaths = [];
  String _path = '';
  String? _error;
  bool _isLoading = false;
  FileManagerLocationType _locationType = FileManagerLocationType.local;
  FileManagerConnection? _connection;
  FTPConnect? _ftp;
  Smb2Pool? _smb;
  String? _clipboardPath;
  bool _clipboardIsCut = false;

  List<FileManagerEntry> get entries => _entries;
  List<FileManagerConnection> get connections => _connections;
  List<String> get favoritePaths => _favoritePaths;
  String get path => _path;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isRemote => _locationType != FileManagerLocationType.local;
  bool get canGoUp => _path.isNotEmpty && _path != p.rootPrefix(_path);
  FileManagerConnection? get connection => _connection;
  bool get canPaste => _clipboardPath != null;
  bool get clipboardIsCut => _clipboardIsCut;

  Future<void> initialize() async {
    final settings = await DatabaseService.instance.getAllSettings(
      FileManagerTool.config.id,
    );
    _connections = _decodeConnections(settings[_connectionsKey]);
    _favoritePaths = _decodeStrings(settings[_favoritesKey]);
    if (await FileManagerStorageAccess.hasAllFilesAccess()) {
      final sharedPath = await FileManagerStorageAccess.externalStoragePath();
      if (sharedPath != null) {
        await openLocal(sharedPath);
        return;
      }
    }
    final documents = await getApplicationDocumentsDirectory();
    await openLocal(documents.path);
  }

  Future<void> openLocal(String directory) async {
    await _disconnectRemote();
    _locationType = FileManagerLocationType.local;
    _connection = null;
    await _load(() async {
      final dir = Directory(directory);
      final entities = await dir.list(followLinks: false).toList();
      _entries = await Future.wait(
        entities.map((entity) async {
          final stat = await entity.stat();
          return FileManagerEntry(
            name: p.basename(entity.path),
            path: entity.path,
            isDirectory: entity is Directory,
            size: entity is File ? stat.size : null,
            modified: stat.modified,
          );
        }),
      );
      _entries.sort(_compareEntries);
      _path = dir.path;
    });
  }

  Future<void> openConnection(FileManagerConnection profile) async {
    await _disconnectRemote();
    _connection = profile;
    _locationType = profile.protocol == FileManagerProtocol.ftp
        ? FileManagerLocationType.ftp
        : FileManagerLocationType.smb;
    final password = await _secureStorage.read(key: _passwordKey(profile.id));
    await _load(() async {
      if (profile.protocol == FileManagerProtocol.ftp) {
        _ftp = FTPConnect(
          profile.host,
          port: profile.port,
          user: profile.username.isEmpty ? 'anonymous' : profile.username,
          pass: password ?? '',
        );
        await _ftp!.connect();
        if (profile.initialPath.isNotEmpty) {
          await _ftp!.changeDirectory(profile.initialPath);
        }
        _path = await _ftp!.currentDirectory();
        await _loadFtpEntries();
      } else {
        if (profile.share.isEmpty) throw Exception('An SMB share is required.');
        _smb = await Smb2Pool.connect(
          host: profile.host,
          share: profile.share,
          user: profile.username,
          password: password ?? '',
        );
        _path = profile.initialPath;
        await _loadSmbEntries();
      }
    });
  }

  Future<void> openEntry(FileManagerEntry entry) async {
    if (!entry.isDirectory) return;
    if (_locationType == FileManagerLocationType.local) {
      return openLocal(entry.path);
    }
    await _load(() async {
      if (_locationType == FileManagerLocationType.ftp) {
        await _ftp!.changeDirectory(entry.name);
        _path = await _ftp!.currentDirectory();
        await _loadFtpEntries();
      } else {
        _path = _joinRemotePath(_path, entry.name);
        await _loadSmbEntries();
      }
    });
  }

  Future<void> goUp() async {
    if (_locationType == FileManagerLocationType.local) {
      return openLocal(p.dirname(_path));
    }
    await _load(() async {
      if (_locationType == FileManagerLocationType.ftp) {
        await _ftp!.changeDirectory('..');
        _path = await _ftp!.currentDirectory();
        await _loadFtpEntries();
      } else {
        _path = _remoteParent(_path);
        await _loadSmbEntries();
      }
    });
  }

  Future<String?> prepareForOpen(
    FileManagerEntry entry,
    String tempPath,
  ) async {
    if (_locationType == FileManagerLocationType.local) return entry.path;
    await _load(() async {
      final target = File(tempPath);
      if (_locationType == FileManagerLocationType.ftp) {
        final ok = await _ftp!.downloadFile(entry.name, target);
        if (!ok) throw Exception('FTP download failed.');
      } else {
        await _smb!.downloadToFile(_joinRemotePath(_path, entry.name), target);
      }
    });
    return _error == null ? tempPath : null;
  }

  Future<void> createFolder(String name) async {
    await _load(() async {
      if (_locationType == FileManagerLocationType.local) {
        await Directory(p.join(_path, name)).create();
      } else if (_locationType == FileManagerLocationType.ftp) {
        await _ftp!.makeDirectory(name);
      } else {
        await _smb!.mkdir(_joinRemotePath(_path, name));
      }
      await refresh();
    });
  }

  Future<void> rename(FileManagerEntry entry, String name) async {
    await _load(() async {
      if (_locationType == FileManagerLocationType.local) {
        final target = p.join(p.dirname(entry.path), name);
        if (entry.isDirectory) {
          await Directory(entry.path).rename(target);
        } else {
          await File(entry.path).rename(target);
        }
      } else if (_locationType == FileManagerLocationType.ftp) {
        await _ftp!.rename(entry.name, name);
      } else {
        await _smb!.rename(
          _joinRemotePath(_path, entry.name),
          _joinRemotePath(_path, name),
        );
      }
      await refresh();
    });
  }

  Future<void> delete(FileManagerEntry entry) async {
    await _load(() async {
      if (_locationType == FileManagerLocationType.local) {
        if (entry.isDirectory) {
          await Directory(entry.path).delete(recursive: true);
        } else {
          await File(entry.path).delete();
        }
      } else if (_locationType == FileManagerLocationType.ftp) {
        if (entry.isDirectory) {
          await _ftp!.deleteDirectory(entry.name);
        } else {
          await _ftp!.deleteFile(entry.name);
        }
      } else if (entry.isDirectory) {
        await _smb!.rmdir(_joinRemotePath(_path, entry.name));
      } else {
        await _smb!.deleteFile(_joinRemotePath(_path, entry.name));
      }
      await refresh();
    });
  }

  void copy(FileManagerEntry entry) {
    if (_locationType != FileManagerLocationType.local) return;
    _clipboardPath = entry.path;
    _clipboardIsCut = false;
    notifyListeners();
  }

  void cut(FileManagerEntry entry) {
    if (_locationType != FileManagerLocationType.local) return;
    _clipboardPath = entry.path;
    _clipboardIsCut = true;
    notifyListeners();
  }

  Future<void> paste() async {
    final sourcePath = _clipboardPath;
    if (sourcePath == null || _locationType != FileManagerLocationType.local) {
      return;
    }
    await _load(() async {
      final destination = p.join(_path, p.basename(sourcePath));
      if (p.equals(sourcePath, destination)) return;
      if (await FileSystemEntity.type(destination) !=
          FileSystemEntityType.notFound) {
        throw Exception('A file or folder with this name already exists.');
      }
      final sourceType = await FileSystemEntity.type(sourcePath);
      if (sourceType == FileSystemEntityType.directory) {
        if (_clipboardIsCut) {
          await Directory(sourcePath).rename(destination);
        } else {
          await _copyDirectory(Directory(sourcePath), Directory(destination));
        }
      } else if (sourceType == FileSystemEntityType.file) {
        if (_clipboardIsCut) {
          await File(sourcePath).rename(destination);
        } else {
          await File(sourcePath).copy(destination);
        }
      } else {
        throw Exception('The selected item is no longer available.');
      }
      if (_clipboardIsCut) {
        _clipboardPath = null;
        _clipboardIsCut = false;
      }
      await refresh();
    });
  }

  Future<void> refresh() async {
    if (_locationType == FileManagerLocationType.local) return openLocal(_path);
    await _load(() async {
      if (_locationType == FileManagerLocationType.ftp) {
        await _loadFtpEntries();
      } else {
        await _loadSmbEntries();
      }
    });
  }

  Future<void> toggleFavorite() async {
    if (isRemote) return;
    if (_favoritePaths.contains(_path)) {
      _favoritePaths.remove(_path);
    } else {
      _favoritePaths.add(_path);
    }
    await DatabaseService.instance.setSetting(
      FileManagerTool.config.id,
      _favoritesKey,
      jsonEncode(_favoritePaths),
    );
    notifyListeners();
  }

  Future<void> saveConnection(
    FileManagerConnection profile,
    String password,
  ) async {
    _connections = [
      ..._connections.where((connection) => connection.id != profile.id),
      profile,
    ];
    await _secureStorage.write(key: _passwordKey(profile.id), value: password);
    await _persistConnections();
    notifyListeners();
  }

  Future<void> removeConnection(FileManagerConnection profile) async {
    _connections.removeWhere((connection) => connection.id == profile.id);
    await _secureStorage.delete(key: _passwordKey(profile.id));
    await _persistConnections();
    notifyListeners();
  }

  Future<void> _loadFtpEntries() async {
    final content = await _ftp!.listDirectoryContent();
    _entries =
        content
            .where((entry) => entry.name != '.' && entry.name != '..')
            .map(
              (entry) => FileManagerEntry(
                name: entry.name,
                path: entry.name,
                isDirectory: entry.type == FTPEntryType.dir,
                size: entry.size,
                modified: entry.modifyTime,
              ),
            )
            .toList()
          ..sort(_compareEntries);
  }

  Future<void> _loadSmbEntries() async {
    final content = await _smb!.listDirectory(_path);
    _entries =
        content
            .where((entry) => entry.name != '.' && entry.name != '..')
            .map(
              (entry) => FileManagerEntry(
                name: entry.name,
                path: _joinRemotePath(_path, entry.name),
                isDirectory: entry.isDirectory,
                size: entry.size,
                modified: entry.stat.modified.toLocal(),
              ),
            )
            .toList()
          ..sort(_compareEntries);
  }

  Future<void> _load(Future<void> Function() operation) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await operation();
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
      debugPrint('[FileManagerState] $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _disconnectRemote() async {
    await _ftp?.disconnect();
    await _smb?.disconnect();
    _ftp = null;
    _smb = null;
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(followLinks: false)) {
      final target = p.join(destination.path, p.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(target));
      } else if (entity is File) {
        await entity.copy(target);
      }
    }
  }

  Future<void> _persistConnections() => DatabaseService.instance.setSetting(
    FileManagerTool.config.id,
    _connectionsKey,
    jsonEncode(_connections.map((profile) => profile.toJson()).toList()),
  );

  List<FileManagerConnection> _decodeConnections(String? source) {
    if (source == null) return [];
    try {
      return (jsonDecode(source) as List<dynamic>)
          .map(
            (entry) =>
                FileManagerConnection.fromJson(entry as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<String> _decodeStrings(String? source) {
    if (source == null) return [];
    try {
      return (jsonDecode(source) as List<dynamic>).cast<String>();
    } catch (_) {
      return [];
    }
  }

  int _compareEntries(FileManagerEntry a, FileManagerEntry b) {
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  String _joinRemotePath(String parent, String name) =>
      parent.isEmpty ? name : '$parent/$name';

  String _remoteParent(String path) {
    final index = path.lastIndexOf('/');
    return index < 0 ? '' : path.substring(0, index);
  }

  String _passwordKey(String id) => '${FileManagerTool.config.id}.password.$id';
}
