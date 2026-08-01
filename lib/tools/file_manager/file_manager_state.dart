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

enum FileManagerOperation { copy, move, delete }

enum FileManagerSortField { name, modified, size }

class FileManagerState extends ChangeNotifier {
  static const _connectionsKey = 'connections';
  static const _favoritesKey = 'favorite_paths';
  static const _sortFieldKey = 'sort_field';
  static const _sortAscendingKey = 'sort_ascending';
  static const _secureStorage = FlutterSecureStorage();

  List<FileManagerEntry> _entries = [];
  List<FileManagerConnection> _connections = [];
  List<String> _favoritePaths = [];
  String _path = '';
  String _appFilesPath = '';
  String? _error;
  bool _isLoading = false;
  FileManagerLocationType _locationType = FileManagerLocationType.local;
  FileManagerConnection? _connection;
  FTPConnect? _ftp;
  Smb2Pool? _smb;
  List<String> _clipboardPaths = [];
  FileManagerLocationType? _clipboardLocationType;
  FileManagerConnection? _clipboardConnection;
  bool _clipboardIsCut = false;
  final Set<String> _selectedPaths = {};
  bool _isSelectionMode = false;
  int _operationCompleted = 0;
  int _operationTotal = 0;
  FileManagerOperation? _operation;
  FileManagerSortField _sortField = FileManagerSortField.name;
  bool _sortAscending = true;

  List<FileManagerEntry> get entries => _entries;
  List<FileManagerConnection> get connections => _connections;
  List<String> get favoritePaths => _favoritePaths;
  String get path => _path;
  String get appFilesPath => _appFilesPath;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isRemote => _locationType != FileManagerLocationType.local;
  bool get canGoUp => _path.isNotEmpty && _path != p.rootPrefix(_path);
  FileManagerConnection? get connection => _connection;
  bool get canPaste => _clipboardPaths.isNotEmpty;
  bool get clipboardIsCut => _clipboardIsCut;
  int get clipboardItemCount => _clipboardPaths.length;
  Set<String> get selectedPaths => Set.unmodifiable(_selectedPaths);
  bool get hasSelection => _selectedPaths.isNotEmpty;
  bool get isSelectionMode => _isSelectionMode;
  bool get isOperating => _operationTotal > 0;
  double? get operationProgress =>
      _operationTotal == 0 ? null : _operationCompleted / _operationTotal;
  int get operationCompleted => _operationCompleted;
  int get operationTotal => _operationTotal;
  FileManagerOperation? get operation => _operation;
  FileManagerSortField get sortField => _sortField;
  bool get sortAscending => _sortAscending;

  Future<void> initialize() async {
    final settings = await DatabaseService.instance.getAllSettings(
      FileManagerTool.config.id,
    );
    _connections = _decodeConnections(settings[_connectionsKey]);
    _favoritePaths = _decodeStrings(settings[_favoritesKey]);
    _sortField = FileManagerSortField.values.firstWhere(
      (field) => field.name == settings[_sortFieldKey],
      orElse: () => FileManagerSortField.name,
    );
    _sortAscending = settings[_sortAscendingKey] != 'false';
    if (await FileManagerStorageAccess.hasAllFilesAccess()) {
      final sharedPath = await FileManagerStorageAccess.externalStoragePath();
      if (sharedPath != null) {
        _appFilesPath = sharedPath;
        await openLocal(sharedPath);
        return;
      }
    }
    final documents = await getApplicationDocumentsDirectory();
    _appFilesPath = documents.path;
    await openLocal(documents.path);
  }

  Future<void> openLocal(String directory) async {
    _locationType = FileManagerLocationType.local;
    _connection = null;
    await _disconnectRemote();
    await _load(() async {
      final dir = Directory(directory);
      final entities = await dir.list(followLinks: false).toList();
      _entries = await Future.wait(entities.map(_localEntryFromEntity));
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
    _isSelectionMode = true;
    if (!_selectedPaths.add(entry.path)) _selectedPaths.remove(entry.path);
    notifyListeners();
  }

  void enterSelectionMode() {
    _isSelectionMode = true;
    notifyListeners();
  }

  void selectAll() {
    _isSelectionMode = true;
    _selectedPaths
      ..clear()
      ..addAll(_entries.map((entry) => entry.path));
    notifyListeners();
  }

  void clearSelection() {
    _selectedPaths.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  void clearClipboard() {
    _clipboardPaths = [];
    _clipboardLocationType = null;
    _clipboardConnection = null;
    _clipboardIsCut = false;
    notifyListeners();
  }

  void copy(FileManagerEntry entry) {
    if (_locationType == FileManagerLocationType.ftp) return;
    _clipboardPaths = _selectedPaths.isEmpty
        ? [entry.path]
        : _selectedPaths.toList();
    _clipboardLocationType = _locationType;
    _clipboardConnection = _connection;
    _clipboardIsCut = false;
    notifyListeners();
  }

  void cut(FileManagerEntry entry) {
    if (_locationType == FileManagerLocationType.ftp) return;
    _clipboardPaths = _selectedPaths.isEmpty
        ? [entry.path]
        : _selectedPaths.toList();
    _clipboardLocationType = _locationType;
    _clipboardConnection = _connection;
    _clipboardIsCut = true;
    notifyListeners();
  }

  Future<void> paste() async {
    if (_clipboardPaths.isEmpty) return;
    if (_clipboardLocationType == FileManagerLocationType.local &&
        _locationType == FileManagerLocationType.local) {
      await _runLocalOperation(
        _clipboardPaths,
        destination: _path,
        move: _clipboardIsCut,
      );
    } else if (_clipboardLocationType == FileManagerLocationType.smb &&
        _locationType == FileManagerLocationType.smb &&
        _clipboardConnection?.id == _connection?.id) {
      await _pasteSmb();
    } else if (_clipboardLocationType == FileManagerLocationType.local &&
        _locationType == FileManagerLocationType.smb) {
      await _pasteLocalToSmb();
    } else if (_clipboardLocationType == FileManagerLocationType.smb &&
        _locationType == FileManagerLocationType.local) {
      await _pasteSmbToLocal();
    } else {
      return;
    }
    if (_clipboardIsCut && _error == null) {
      clearClipboard();
    }
  }

  Future<void> _pasteLocalToSmb() async {
    final smb = _smb;
    if (smb == null) return;
    await _runNetworkOperation(() async {
      for (final source in _clipboardPaths) {
        await _copyLocalEntityToSmb(
          smb,
          source,
          _joinRemotePath(_path, p.basename(source)),
        );
        if (_clipboardIsCut) await _deleteLocalEntity(source);
        _reportNetworkProgress();
      }
      await refresh();
    });
  }

  Future<void> _pasteSmbToLocal() async {
    final profile = _clipboardConnection;
    if (profile == null) return;
    final password = await _secureStorage.read(key: _passwordKey(profile.id));
    final smb = await Smb2Pool.connect(
      host: profile.host,
      share: profile.share,
      user: profile.username,
      password: password ?? '',
    );
    try {
      await _runNetworkOperation(() async {
        for (final source in _clipboardPaths) {
          await _copySmbEntityToLocal(
            smb,
            source,
            p.join(_path, p.basename(source)),
          );
          if (_clipboardIsCut) await _deleteSmbEntity(smb, source);
          _reportNetworkProgress();
        }
        await refresh();
      });
    } finally {
      await smb.disconnect();
    }
  }

  Future<void> _pasteSmb() async {
    final smb = _smb;
    if (smb == null) return;
    await _runNetworkOperation(() async {
      for (final source in _clipboardPaths) {
        final destination = _joinRemotePath(_path, p.basename(source));
        if (source == destination) continue;
        if (_clipboardIsCut) {
          await smb.rename(source, destination);
        } else {
          await _copySmbEntity(smb, source, destination);
        }
        _reportNetworkProgress();
      }
      await refresh();
    });
  }

  Future<void> _runNetworkOperation(Future<void> Function() action) async {
    _isLoading = true;
    _error = null;
    _operation = _clipboardIsCut
        ? FileManagerOperation.move
        : FileManagerOperation.copy;
    _operationCompleted = 0;
    _operationTotal = _clipboardPaths.length;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
      debugPrint('[FileManagerState] $error');
    } finally {
      _isLoading = false;
      _operation = null;
      _operationCompleted = 0;
      _operationTotal = 0;
      notifyListeners();
    }
  }

  void _reportNetworkProgress() {
    _operationCompleted++;
    notifyListeners();
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
    _operation = delete
        ? FileManagerOperation.delete
        : move
        ? FileManagerOperation.move
        : FileManagerOperation.copy;
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
      _operation = null;
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

  Future<void> updateSort(FileManagerSortField field, bool ascending) async {
    _sortField = field;
    _sortAscending = ascending;
    _entries.sort(_compareEntries);
    await DatabaseService.instance.setSetting(
      FileManagerTool.config.id,
      _sortFieldKey,
      field.name,
    );
    await DatabaseService.instance.setSetting(
      FileManagerTool.config.id,
      _sortAscendingKey,
      ascending.toString(),
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

  Future<FileManagerEntry> _localEntryFromEntity(
    FileSystemEntity entity,
  ) async {
    final stat = await entity.stat();
    var isDirectory = entity is Directory;
    var entryPath = entity.path;
    if (entity is Directory || entity is Link) {
      try {
        final resolvedPath = await entity.resolveSymbolicLinks();
        if (await Directory(resolvedPath).exists()) {
          isDirectory = true;
          entryPath = resolvedPath;
        }
      } catch (_) {
        // Some Windows compatibility junctions intentionally deny resolution.
      }
    }
    return FileManagerEntry(
      name: p.basename(entity.path),
      path: entryPath,
      isDirectory: isDirectory,
      size: isDirectory ? null : stat.size,
      modified: stat.modified,
    );
  }

  Future<void> _safeDisconnectFtp(FTPConnect ftp) async {
    try {
      await ftp.disconnect();
    } catch (error) {
      debugPrint('[FileManagerState] FTP disconnect failed: $error');
    }
  }

  Future<void> _copySmbEntity(
    Smb2Pool smb,
    String source,
    String destination,
  ) async {
    final stat = await smb.stat(source);
    if (stat.isDirectory) {
      await smb.mkdir(destination);
      final entries = await smb.listDirectory(source);
      for (final entry in entries) {
        if (entry.name == '.' || entry.name == '..') continue;
        await _copySmbEntity(
          smb,
          _joinRemotePath(source, entry.name),
          _joinRemotePath(destination, entry.name),
        );
      }
      return;
    }
    await smb.writeFile(destination, await smb.readFile(source));
  }

  Future<void> _copyLocalEntityToSmb(
    Smb2Pool smb,
    String source,
    String destination,
  ) async {
    final type = await FileSystemEntity.type(source, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await smb.mkdir(destination);
      await for (final child in Directory(source).list(followLinks: false)) {
        await _copyLocalEntityToSmb(
          smb,
          child.path,
          _joinRemotePath(destination, p.basename(child.path)),
        );
      }
      return;
    }
    await smb.writeFile(destination, await File(source).readAsBytes());
  }

  Future<void> _copySmbEntityToLocal(
    Smb2Pool smb,
    String source,
    String destination,
  ) async {
    final stat = await smb.stat(source);
    if (stat.isDirectory) {
      await Directory(destination).create();
      for (final entry in await smb.listDirectory(source)) {
        if (entry.name == '.' || entry.name == '..') continue;
        await _copySmbEntityToLocal(
          smb,
          _joinRemotePath(source, entry.name),
          p.join(destination, entry.name),
        );
      }
      return;
    }
    await File(destination).writeAsBytes(await smb.readFile(source));
  }

  Future<void> _deleteLocalEntity(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else {
      await File(path).delete();
    }
  }

  Future<void> _deleteSmbEntity(Smb2Pool smb, String path) async {
    final stat = await smb.stat(path);
    if (stat.isDirectory) {
      for (final entry in await smb.listDirectory(path)) {
        if (entry.name == '.' || entry.name == '..') continue;
        await _deleteSmbEntity(smb, _joinRemotePath(path, entry.name));
      }
      await smb.rmdir(path);
    } else {
      await smb.deleteFile(path);
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
    final comparison = switch (_sortField) {
      FileManagerSortField.name => a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      ),
      FileManagerSortField.modified => (a.modified ?? DateTime(0)).compareTo(
        b.modified ?? DateTime(0),
      ),
      FileManagerSortField.size => (a.size ?? 0).compareTo(b.size ?? 0),
    };
    return _sortAscending ? comparison : -comparison;
  }

  String _joinRemotePath(String parent, String name) =>
      parent.isEmpty ? name : '$parent/$name';

  String _remoteParent(String path) {
    final index = path.lastIndexOf('/');
    return index < 0 ? '' : path.substring(0, index);
  }

  String _passwordKey(String id) => '${FileManagerTool.config.id}.password.$id';
}
