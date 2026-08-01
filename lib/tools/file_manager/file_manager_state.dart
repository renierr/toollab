import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dart_smb2/dart_smb2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/foreground_runtime_service.dart';
import 'package:tool_lab/tools/file_manager/config.dart';
import 'package:tool_lab/tools/file_manager/file_manager_connection.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';
import 'package:tool_lab/tools/file_manager/file_manager_storage_access.dart';
import 'package:tool_lab/tools/file_manager/file_manager_operation_worker.dart';

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
  List<String> _clipboardPaths = [];
  bool _clipboardIsCut = false;
  final Set<String> _selectedPaths = {};
  int _operationCompleted = 0;
  int _operationTotal = 0;

  List<FileManagerEntry> get entries => _entries;
  List<FileManagerConnection> get connections => _connections;
  List<String> get favoritePaths => _favoritePaths;
  String get path => _path;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isRemote => _locationType != FileManagerLocationType.local;
  bool get canGoUp => _path.isNotEmpty && _path != p.rootPrefix(_path);
  FileManagerConnection? get connection => _connection;
  bool get canPaste => _clipboardPaths.isNotEmpty;
  bool get clipboardIsCut => _clipboardIsCut;
  Set<String> get selectedPaths => Set.unmodifiable(_selectedPaths);
  bool get hasSelection => _selectedPaths.isNotEmpty;
  bool get isOperating => _operationTotal > 0;
  double? get operationProgress =>
      _operationTotal == 0 ? null : _operationCompleted / _operationTotal;

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
    _locationType = FileManagerLocationType.local;
    _connection = null;
    await _disconnectRemote();
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
    final password = await _secureStorage.read(key: _passwordKey(profile.id));
    await _load(() async {
      if (profile.protocol == FileManagerProtocol.ftp) {
        final ftp = FTPConnect(
          profile.host,
          port: profile.port,
          user: profile.username.isEmpty ? 'anonymous' : profile.username,
          pass: password ?? '',
        );
        try {
          await ftp.connect();
          if (profile.initialPath.isNotEmpty) {
            final changed = await ftp.changeDirectory(profile.initialPath);
            if (!changed) {
              throw Exception('FTP start folder could not be opened.');
            }
          }
          _path = await ftp.currentDirectory();
          _ftp = ftp;
          _locationType = FileManagerLocationType.ftp;
          _connection = profile;
          await _loadFtpEntries();
        } catch (_) {
          await _safeDisconnectFtp(ftp);
          rethrow;
        }
      } else {
        if (profile.share.isEmpty) throw Exception('An SMB share is required.');
        final smb = await Smb2Pool.connect(
          host: profile.host,
          share: profile.share,
          user: profile.username,
          password: password ?? '',
        );
        try {
          _path = profile.initialPath;
          _smb = smb;
          _locationType = FileManagerLocationType.smb;
          _connection = profile;
          await _loadSmbEntries();
        } catch (_) {
          _smb = null;
          await smb.disconnect();
          rethrow;
        }
      }
    });
  }

  Future<List<String>> discoverSmbShares({
    required String host,
    required String username,
    required String password,
  }) async {
    if (host.trim().isEmpty) throw Exception('Enter an SMB host first.');
    final shares = await Smb2Pool.listSharesOn(
      host: host.trim(),
      user: username.trim().isEmpty ? null : username.trim(),
      password: password,
    );
    return shares
        .where((share) => share.isDisk)
        .map((share) => share.name)
        .toList();
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
        final ftp = _ftp;
        if (ftp == null) throw Exception('FTP connection is no longer active.');
        final ok = await ftp.downloadFile(entry.name, target);
        if (!ok) throw Exception('FTP download failed.');
      } else {
        final smb = _smb;
        if (smb == null) throw Exception('SMB connection is no longer active.');
        await smb.downloadToFile(_joinRemotePath(_path, entry.name), target);
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

  void toggleSelection(FileManagerEntry entry) {
    if (!_selectedPaths.add(entry.path)) _selectedPaths.remove(entry.path);
    notifyListeners();
  }

  void clearSelection() {
    _selectedPaths.clear();
    notifyListeners();
  }

  void copy(FileManagerEntry entry) {
    if (_locationType != FileManagerLocationType.local) return;
    _clipboardPaths = _selectedPaths.isEmpty
        ? [entry.path]
        : _selectedPaths.toList();
    _clipboardIsCut = false;
    notifyListeners();
  }

  void cut(FileManagerEntry entry) {
    if (_locationType != FileManagerLocationType.local) return;
    _clipboardPaths = _selectedPaths.isEmpty
        ? [entry.path]
        : _selectedPaths.toList();
    _clipboardIsCut = true;
    notifyListeners();
  }

  Future<void> paste() async {
    if (_clipboardPaths.isEmpty ||
        _locationType != FileManagerLocationType.local) {
      return;
    }
    await _runLocalOperation(
      _clipboardPaths,
      destination: _path,
      move: _clipboardIsCut,
    );
    if (_clipboardIsCut && _error == null) {
      _clipboardPaths = [];
      _clipboardIsCut = false;
    }
  }

  Future<void> deleteSelected() async {
    if (_locationType == FileManagerLocationType.local) {
      await _runLocalOperation(_selectedPaths.toList(), delete: true);
      return;
    }
    final selected = _entries
        .where((entry) => _selectedPaths.contains(entry.path))
        .toList();
    await _load(() async {
      for (final entry in selected) {
        if (_locationType == FileManagerLocationType.ftp) {
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
      }
      _selectedPaths.clear();
      await refresh();
    });
  }

  Future<void> _runLocalOperation(
    List<String> sources, {
    String destination = '',
    bool move = false,
    bool delete = false,
  }) async {
    if (sources.isEmpty || _locationType != FileManagerLocationType.local) {
      return;
    }
    _isLoading = true;
    _error = null;
    _operationCompleted = 0;
    _operationTotal = 1;
    notifyListeners();
    final lease = await ForegroundRuntimeService.acquire(
      title: 'File Manager',
      text: delete
          ? 'Deleting files'
          : move
          ? 'Moving files'
          : 'Copying files',
    );
    final port = ReceivePort();
    try {
      await Isolate.spawn(runFileManagerOperation, {
        'sendPort': port.sendPort,
        'sources': sources,
        'destination': destination,
        'move': move,
        'delete': delete,
      });
      await for (final message in port) {
        final data = message as Map<Object?, Object?>;
        if (data['type'] == 'progress') {
          _operationCompleted = data['completed']! as int;
          _operationTotal = data['total']! as int;
          notifyListeners();
          await lease.update(
            title: 'File Manager',
            text:
                '${delete
                    ? 'Deleting'
                    : move
                    ? 'Moving'
                    : 'Copying'} $_operationCompleted of $_operationTotal files',
          );
        } else if (data['type'] == 'error') {
          throw Exception(data['message']);
        } else {
          break;
        }
      }
      _selectedPaths.clear();
      await refresh();
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      port.close();
      _isLoading = false;
      _operationCompleted = 0;
      _operationTotal = 0;
      await lease.release();
      notifyListeners();
    }
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
    final ftp = _ftp;
    final smb = _smb;
    _ftp = null;
    _smb = null;
    if (ftp != null) await _safeDisconnectFtp(ftp);
    if (smb != null) {
      try {
        await smb.disconnect();
      } catch (error) {
        debugPrint('[FileManagerState] SMB disconnect failed: $error');
      }
    }
  }

  Future<void> _safeDisconnectFtp(FTPConnect ftp) async {
    try {
      await ftp.disconnect();
    } catch (error) {
      debugPrint('[FileManagerState] FTP disconnect failed: $error');
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
