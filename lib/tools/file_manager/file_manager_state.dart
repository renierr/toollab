import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:dart_smb2/dart_smb2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tool_lab/helpers/mime_type_helper.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/foreground_runtime_service.dart';
import 'package:tool_lab/tools/file_manager/config.dart';
import 'package:tool_lab/tools/file_manager/archives/archive_handler.dart';
import 'package:tool_lab/tools/file_manager/archives/zip_archive_handler.dart';
import 'package:tool_lab/tools/file_manager/file_manager_connection.dart';
import 'package:tool_lab/tools/file_manager/file_manager_storage_access.dart';
import 'package:tool_lab/tools/file_manager/file_manager_operation_worker.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';

enum FileManagerLocationType { local, ftp, smb }

enum FileManagerOperation { copy, move, delete, compress, extract }

enum FileManagerConflictResolution { overwrite, keepBoth }

enum FileManagerSortField { name, modified, size }

enum FileManagerOpenCategory { images, pdf, audio, video, markdown }

class FileManagerState extends ChangeNotifier {
  static const _connectionsKey = 'connections';
  static const _favoritesKey = 'favorite_paths';
  static const _recentPathsKey = 'recent_paths';
  static const _sortFieldKey = 'sort_field';
  static const _sortAscendingKey = 'sort_ascending';
  static const _foldersFirstKey = 'folders_first';
  static const _startupPathKey = 'startup_path';
  static const _openToolPrefix = 'open_tool_';
  static const _secureStorage = FlutterSecureStorage();

  List<FileManagerEntry> _entries = [];
  List<FileManagerConnection> _connections = [];
  List<String> _favoritePaths = [];
  List<String> _recentPaths = [];
  List<String> _drives = [];
  String _path = '';
  String? _archivePath;
  String _archiveDirectory = '';
  String _appFilesPath = '';
  String _downloadsPath = '';
  String? _startupPath;
  bool _hasAllFilesAccess = true;
  String? _error;
  bool _isLoading = false;
  FileManagerLocationType _locationType = FileManagerLocationType.local;
  FileManagerConnection? _connection;
  FTPConnect? _ftp;
  Smb2Pool? _smb;
  List<String> _clipboardPaths = [];
  List<FileManagerEntry> _archiveClipboardEntries = [];
  FileManagerLocationType? _clipboardLocationType;
  FileManagerConnection? _clipboardConnection;
  bool _clipboardIsCut = false;
  final Set<String> _selectedPaths = {};
  bool _isSelectionMode = false;
  int _operationCompleted = 0;
  int _operationTotal = 0;
  FileManagerOperation? _operation;
  final List<String> _operationErrors = [];
  FileManagerSortField _sortField = FileManagerSortField.name;
  FileManagerSortField? _sortOverride;
  String? _sortOverridePath;
  bool _sortAscending = true;
  bool _foldersFirst = true;
  final Map<FileManagerOpenCategory, String?> _openToolIds = {};
  final Map<String, ValueNotifier<FileStat?>> _metadata = {};
  final ValueNotifier<FileStat?> _emptyMetadata = ValueNotifier<FileStat?>(
    null,
  );
  final List<FileManagerEntry> _metadataQueue = [];
  final Set<String> _queuedMetadataPaths = {};
  int _activeMetadataLoads = 0;
  final Map<String, ValueNotifier<int?>> _childCounts = {};
  final ValueNotifier<int?> _emptyChildCount = ValueNotifier<int?>(null);
  final List<String> _childCountQueue = [];
  final Set<String> _queuedChildCountPaths = {};
  int _activeChildCountLoads = 0;
  int _metadataScan = 0;
  int _listing = 0;
  bool _isScanningMetadata = false;
  static const List<ArchiveHandler> _archiveHandlers = [ZipArchiveHandler()];

  List<FileManagerEntry> get entries => _entries;
  List<FileManagerConnection> get connections => _connections;
  List<String> get favoritePaths => _favoritePaths;
  List<String> get recentPaths => _recentPaths;

  /// Windows drive roots (`C:\`, `D:\`, …); empty on every other platform.
  List<String> get drives => _drives;
  String get path =>
      isArchiveBrowsing ? '${_archivePath!}::$_archiveDirectory' : _path;
  String get archivePath => _archivePath ?? '';
  String get archiveDirectory => _archiveDirectory;
  String get appFilesPath => _appFilesPath;
  String get defaultFolderPath => _startupPath ?? _appFilesPath;
  String get locationLabel =>
      isArchiveBrowsing ? p.basename(_archivePath!) : _displayPath(_path);
  String get downloadsPath => _downloadsPath;
  bool get usesSharedStorage =>
      FileManagerStorageAccess.isAndroid && _hasAllFilesAccess;
  String get sharedStoragePath => p.dirname(_appFilesPath);
  String? get startupPath => _startupPath;
  bool get requiresStorageAccess =>
      FileManagerStorageAccess.isAndroid && !_hasAllFilesAccess;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isScanningMetadata => _isScanningMetadata;

  /// Bumped every time a local listing is (re)loaded, so the page can tell a
  /// refresh of the same folder apart from a plain rebuild.
  int get listingGeneration => _listing;
  bool get isRemote => _locationType != FileManagerLocationType.local;
  bool get isArchiveBrowsing => _archivePath != null;
  bool get isReadOnly => isArchiveBrowsing;
  bool get canGoUp {
    if (isArchiveBrowsing) return true;
    if (_path.isEmpty || _path == p.rootPrefix(_path)) return false;
    if (FileManagerStorageAccess.isAndroid &&
        _hasAllFilesAccess &&
        _appFilesPath.isNotEmpty) {
      return !p.equals(_path, p.dirname(_appFilesPath));
    }
    return true;
  }

  bool get canNavigateBack =>
      isArchiveBrowsing ||
      _locationType != FileManagerLocationType.local ||
      !p.equals(_path, defaultFolderPath);

  FileManagerConnection? get connection => _connection;
  bool get canPaste =>
      _clipboardPaths.isNotEmpty || _archiveClipboardEntries.isNotEmpty;
  bool get clipboardIsCut => _clipboardIsCut;
  int get clipboardItemCount => _archiveClipboardEntries.isNotEmpty
      ? _archiveClipboardEntries.length
      : _clipboardPaths.length;
  List<String> get clipboardPaths => List.unmodifiable(_clipboardPaths);
  Set<String> get selectedPaths => Set.unmodifiable(_selectedPaths);
  bool get hasSelection => _selectedPaths.isNotEmpty;
  bool get isSelectionMode => _isSelectionMode;
  bool get isOperating => _operation != null;
  double? get operationProgress =>
      _operationTotal == 0 ? null : _operationCompleted / _operationTotal;
  int get operationCompleted => _operationCompleted;
  int get operationTotal => _operationTotal;
  FileManagerOperation? get operation => _operation;
  FileManagerSortField get sortField => _sortField;

  /// The folder-local sort chosen via the explorer toggle, or null once the
  /// folder changed.
  FileManagerSortField? get _activeOverride {
    final override = _sortOverride;
    return override != null && _sortOverridePath == path ? override : null;
  }

  FileManagerSortField get activeSortField => _activeOverride ?? _sortField;

  /// A toggled name sort is always A-Z, regardless of the persisted direction.
  bool get activeSortAscending =>
      _activeOverride == FileManagerSortField.name ? true : _sortAscending;

  bool get sortAscending => _sortAscending;
  bool get foldersFirst => _foldersFirst;
  String? openToolId(FileManagerOpenCategory category) =>
      _openToolIds[category];

  ValueListenable<FileStat?> metadataFor(FileManagerEntry entry) {
    if (entry.modified != null || entry.isArchiveEntry || isRemote) {
      return _emptyMetadata;
    }
    final notifier = _metadata.putIfAbsent(
      entry.path,
      () => ValueNotifier<FileStat?>(null),
    );
    if (!_queuedMetadataPaths.contains(entry.path) && notifier.value == null) {
      _queuedMetadataPaths.add(entry.path);
      _metadataQueue.add(entry);
      _startMetadataLoads();
    }
    return notifier;
  }

  void _startMetadataLoads() {
    while (_activeMetadataLoads < 2 && _metadataQueue.isNotEmpty) {
      final entry = _metadataQueue.removeAt(0);
      _activeMetadataLoads++;
      FileStat.stat(entry.path)
          .then((stat) => _metadata[entry.path]?.value = stat)
          .catchError((_) => null)
          .whenComplete(() {
            _activeMetadataLoads--;
            _startMetadataLoads();
          });
    }
  }

  /// Lazily counts a folder's direct children, one visible row at a time so a
  /// deep tree never stalls the listing.
  ValueListenable<int?> childCountFor(FileManagerEntry entry) {
    if (!entry.isDirectory ||
        entry.isBrokenLink ||
        entry.isArchiveEntry ||
        isRemote) {
      return _emptyChildCount;
    }
    final notifier = _childCounts.putIfAbsent(
      entry.path,
      () => ValueNotifier<int?>(null),
    );
    if (!_queuedChildCountPaths.contains(entry.path) &&
        notifier.value == null) {
      _queuedChildCountPaths.add(entry.path);
      _childCountQueue.add(entry.path);
      _startChildCountLoads();
    }
    return notifier;
  }

  void _startChildCountLoads() {
    while (_activeChildCountLoads < 2 && _childCountQueue.isNotEmpty) {
      final path = _childCountQueue.removeAt(0);
      _activeChildCountLoads++;
      _countChildren(path)
          .then((count) => _childCounts[path]?.value = count)
          .catchError((_) => null)
          .whenComplete(() {
            _activeChildCountLoads--;
            _startChildCountLoads();
          });
    }
  }

  Future<int?> _countChildren(String path) async {
    try {
      var count = 0;
      await for (final _ in Directory(path).list(followLinks: false)) {
        count++;
      }
      return count;
    } catch (error) {
      return null;
    }
  }

  void _clearEntryLoaders() {
    for (final notifier in _metadata.values) {
      notifier.dispose();
    }
    for (final notifier in _childCounts.values) {
      notifier.dispose();
    }
    _childCounts.clear();
    _childCountQueue.clear();
    _queuedChildCountPaths.clear();
    _activeChildCountLoads = 0;
    _metadata.clear();
    _metadataQueue.clear();
    _queuedMetadataPaths.clear();
    _activeMetadataLoads = 0;
    _metadataScan++;
    _isScanningMetadata = false;
  }

  /// Fills size/modified for the whole listing off the UI isolate so sorting by
  /// modified or size works without stalling the initial name-only render.
  Future<void> _scanLocalMetadata(String directory) async {
    if (_entries.isEmpty) return;
    final scan = ++_metadataScan;
    final paths = _entries.map((entry) => entry.path).toList();
    _isScanningMetadata = true;
    notifyListeners();
    List<List<int>?> stats;
    try {
      stats = await Isolate.run(() => statLocalPaths(paths));
    } catch (error) {
      debugPrint('[FileManagerState] Metadata scan failed: $error');
      if (scan == _metadataScan) {
        _isScanningMetadata = false;
        notifyListeners();
      }
      return;
    }
    if (scan != _metadataScan || _path != directory) return;
    for (
      var index = 0;
      index < paths.length && index < _entries.length;
      index++
    ) {
      final stat = stats[index];
      final entry = _entries[index];
      if (stat == null || entry.path != paths[index]) continue;
      _entries[index] = entry.copyWith(
        size: entry.isDirectory ? null : stat[0],
        modified: DateTime.fromMillisecondsSinceEpoch(stat[1]),
      );
    }
    _entries.sort(_compareEntries);
    _isScanningMetadata = false;
    notifyListeners();
  }

  String _displayPath(String path) {
    if (isRemote) return path.isEmpty ? '/' : path;
    final parts = path
        .replaceAll('\\', '/')
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    const labels = {
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
    for (var index = 0; index < parts.length; index++) {
      final label = labels[parts[index].toLowerCase()];
      if (label != null) return [label, ...parts.skip(index + 1)].join('/');
    }
    return parts.isEmpty
        ? '/'
        : parts.length == 1
        ? parts.first
        : '${parts[parts.length - 2]}/${parts.last}';
  }

  Future<void> initialize() async {
    final settings = await DatabaseService.instance.getAllSettings(
      FileManagerTool.config.id,
    );
    _connections = _decodeConnections(settings[_connectionsKey]);
    _favoritePaths = _decodeStrings(settings[_favoritesKey]);
    _recentPaths = _decodeStrings(settings[_recentPathsKey]);
    _sortField = FileManagerSortField.values.firstWhere(
      (field) => field.name == settings[_sortFieldKey],
      orElse: () => FileManagerSortField.name,
    );
    _sortAscending = settings[_sortAscendingKey] != 'false';
    _foldersFirst = settings[_foldersFirstKey] != 'false';
    _startupPath = settings[_startupPathKey];
    for (final category in FileManagerOpenCategory.values) {
      _openToolIds[category] = settings['$_openToolPrefix${category.name}'];
    }
    await _loadDrives();
    _hasAllFilesAccess = await FileManagerStorageAccess.hasAllFilesAccess();
    if (_hasAllFilesAccess) {
      final sharedPath = await FileManagerStorageAccess.externalStoragePath();
      if (sharedPath != null) {
        _appFilesPath = p.join(sharedPath, 'Documents');
        _downloadsPath = p.join(sharedPath, 'Download');
        await openLocal(await _resolvedStartupPath());
        return;
      }
    }
    final documents = await getApplicationDocumentsDirectory();
    _appFilesPath = _userFolderPath('Documents') ?? documents.path;
    _downloadsPath = _userFolderPath('Downloads') ?? documents.path;
    await openLocal(await _resolvedStartupPath());
  }

  /// Probes the drive letters so fixed, removable and mapped network drives all
  /// show up. Starts at C: because polling A:/B: can stall on legacy hardware.
  Future<void> _loadDrives() async {
    if (!Platform.isWindows) return;
    final roots = <String>[];
    for (var code = 'C'.codeUnitAt(0); code <= 'Z'.codeUnitAt(0); code++) {
      final root = '${String.fromCharCode(code)}:\\';
      try {
        if (await Directory(root).exists()) roots.add(root);
      } catch (_) {
        // An unreadable drive (no medium, offline share) is simply not listed.
      }
    }
    _drives = roots;
  }

  String? _userFolderPath(String folder) {
    if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'];
      return home == null ? null : p.join(home, folder);
    }
    if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      return home == null ? null : p.join(home, folder);
    }
    return null;
  }

  Future<String> _resolvedStartupPath() async {
    final startupPath = _startupPath;
    if (startupPath != null && await Directory(startupPath).exists()) {
      return startupPath;
    }
    return _appFilesPath;
  }

  Future<void> openLocal(String directory) async {
    _archivePath = null;
    _archiveDirectory = '';
    _locationType = FileManagerLocationType.local;
    _connection = null;
    await _disconnectRemote();
    _isLoading = true;
    _error = null;
    _clearEntryLoaders();
    _entries = [];
    _path = directory;
    final listing = ++_listing;
    notifyListeners();
    try {
      final batch = <FileManagerEntry>[];
      await for (final entity in Directory(
        directory,
      ).list(followLinks: false)) {
        // A newer listing (or the tool closing) owns the entries now.
        if (listing != _listing) return;
        // Publish batches so a large directory becomes usable before scanning ends.
        batch.add(await _localEntryFromEntity(entity));
        if (batch.length == 200) {
          _entries.addAll(batch);
          batch.clear();
          notifyListeners();
        }
      }
      if (batch.isNotEmpty) {
        _entries.addAll(batch);
      }
      _entries.sort(_compareEntries);
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
      debugPrint('[FileManagerState] $error');
    } finally {
      if (listing == _listing) {
        _isLoading = false;
        notifyListeners();
      }
    }
    if (_error != null || listing != _listing) return;
    await _recordRecentPath(directory);
    await _scanLocalMetadata(directory);
  }

  Future<void> openPath(String path) async {
    if (isArchiveBrowsing) return _openArchiveDirectory(path);
    if (_locationType == FileManagerLocationType.local) {
      return openLocal(path);
    }
    await _load(() async {
      if (_locationType == FileManagerLocationType.ftp) {
        final changed = await _ftp!.changeDirectory(path);
        if (!changed) throw Exception('Folder could not be opened.');
        _path = await _ftp!.currentDirectory();
        await _loadFtpEntries();
      } else {
        _path = path;
        await _loadSmbEntries();
      }
    });
  }

  Future<void> _openArchive(String archivePath) async {
    _archivePath = archivePath;
    _archiveDirectory = '';
    await _loadArchiveEntries();
  }

  Future<void> _openArchiveDirectory(String directoryPath) async {
    _archiveDirectory = directoryPath == '.' ? '' : directoryPath;
    await _loadArchiveEntries();
  }

  Future<void> _loadArchiveEntries() async {
    final archivePath = _archivePath;
    if (archivePath == null) return;
    await _load(() async {
      final handler = _archiveHandlers.firstWhere(
        (candidate) => candidate.supports(archivePath),
      );
      _entries =
          (await handler.listEntries(
                archivePath: archivePath,
                directoryPath: _archiveDirectory,
              ))
              .map(
                (entry) => FileManagerEntry(
                  name: entry.name,
                  path: '$archivePath::${entry.path}',
                  isDirectory: entry.isDirectory,
                  size: entry.size,
                  modified: entry.modified,
                  archivePath: archivePath,
                  archiveEntryPath: entry.path,
                ),
              )
              .toList()
            ..sort(_compareEntries);
    });
  }

  Future<int?> folderItemCount(FileManagerEntry entry) async {
    if (!entry.isDirectory || isRemote) return null;
    if (entry.isArchiveEntry) {
      final handler = _archiveHandlers.firstWhere(
        (candidate) => candidate.supports(entry.archivePath!),
      );
      return (await handler.listEntries(
        archivePath: entry.archivePath!,
        directoryPath: entry.archiveEntryPath!,
      )).length;
    }
    try {
      return await Directory(entry.path).list(followLinks: false).length;
    } catch (error) {
      debugPrint('[FileManagerState] Folder count failed: $error');
      return null;
    }
  }

  /// Recursive file count shown in the delete confirmation. Local folders only —
  /// walking a remote or archive tree would stall the dialog.
  Future<int?> folderFileCount(FileManagerEntry entry) async {
    if (!entry.isDirectory || isRemote || entry.isArchiveEntry) return null;
    try {
      return await Directory(entry.path)
          .list(recursive: true, followLinks: false)
          .where((child) => child is! Directory)
          .length;
    } catch (error) {
      debugPrint('[FileManagerState] Folder file count failed: $error');
      return null;
    }
  }

  Future<void> _recordRecentPath(String path) async {
    _recentPaths = [
      path,
      ..._recentPaths.where((item) => !p.equals(item, path)),
    ].take(5).toList();
    await DatabaseService.instance.setSetting(
      FileManagerTool.config.id,
      _recentPathsKey,
      jsonEncode(_recentPaths),
    );
    notifyListeners();
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
    if (entry.isArchiveEntry) {
      return _openArchiveDirectory(entry.archiveEntryPath!);
    }
    if (_locationType == FileManagerLocationType.local && canExtract(entry)) {
      return _openArchive(entry.path);
    }
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
    if (!canGoUp) {
      if (canNavigateBack) await openLocal(defaultFolderPath);
      return;
    }
    if (isArchiveBrowsing) {
      if (_archiveDirectory.isEmpty) return openLocal(p.dirname(_archivePath!));
      return _openArchiveDirectory(p.posix.dirname(_archiveDirectory));
    }
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

  /// [tempPathBuilder] is only invoked for sources that need a local copy, so
  /// opening a local file touches no temp storage at all.
  Future<String?> prepareForOpen(
    FileManagerEntry entry,
    Future<String> Function() tempPathBuilder,
  ) async {
    if (entry.isArchiveEntry) {
      final handler = _archiveHandlers.firstWhere(
        (candidate) => candidate.supports(entry.archivePath!),
      );
      final tempPath = await tempPathBuilder();
      await handler.extractEntry(
        archivePath: entry.archivePath!,
        entryPath: entry.archiveEntryPath!,
        destinationPath: p.dirname(tempPath),
      );
      final extractedPath = p.join(p.dirname(tempPath), entry.name);
      if (!await File(extractedPath).exists()) {
        throw Exception('Archive entry could not be extracted.');
      }
      return extractedPath;
    }
    if (_locationType == FileManagerLocationType.local) return entry.path;
    final tempPath = await tempPathBuilder();
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
    String? created;
    await _load(() async {
      if (_locationType == FileManagerLocationType.local) {
        await Directory(p.join(_path, name)).create();
        created = p.join(_path, name);
      } else if (_locationType == FileManagerLocationType.ftp) {
        await _ftp!.makeDirectory(name);
        // FTP navigates relative to the current directory.
        created = name;
      } else {
        await _smb!.mkdir(_joinRemotePath(_path, name));
        created = _joinRemotePath(_path, name);
      }
    });
    final target = created;
    // Drop the user straight into the folder they just made.
    if (_error == null && target != null) return openPath(target);
    await refresh();
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

  /// Targets a single entry for a bulk operation without arming selection mode,
  /// so a row menu action does not turn the whole list into a picker.
  void selectForAction(FileManagerEntry entry) {
    _selectedPaths
      ..clear()
      ..add(entry.path);
    _isSelectionMode = false;
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
    _archiveClipboardEntries = [];
    _clipboardLocationType = null;
    _clipboardConnection = null;
    _clipboardIsCut = false;
    notifyListeners();
  }

  void copy(FileManagerEntry entry) {
    if (_locationType == FileManagerLocationType.ftp) return;
    if (entry.isArchiveEntry) {
      _archiveClipboardEntries = _selectedPaths.isEmpty
          ? [entry]
          : _entries
                .where((item) => _selectedPaths.contains(item.path))
                .toList();
      _clipboardPaths = [];
      _clipboardIsCut = false;
      notifyListeners();
      return;
    }
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

  Future<List<String>> localPasteConflicts() async {
    if (_clipboardLocationType != FileManagerLocationType.local ||
        _locationType != FileManagerLocationType.local) {
      return const [];
    }
    final conflicts = <String>[];
    for (final source in _clipboardPaths) {
      final destination = p.join(_path, p.basename(source));
      if (!p.equals(source, destination) &&
          await FileSystemEntity.type(destination) !=
              FileSystemEntityType.notFound) {
        conflicts.add(p.basename(source));
      }
    }
    return conflicts;
  }

  Future<void> paste({
    FileManagerConflictResolution resolution =
        FileManagerConflictResolution.keepBoth,
  }) async {
    if (isArchiveBrowsing || !canPaste) return;
    if (_archiveClipboardEntries.isNotEmpty) {
      await _pasteArchiveEntries();
      return;
    }
    if (_clipboardLocationType == FileManagerLocationType.local &&
        _locationType == FileManagerLocationType.local) {
      await _runLocalOperation(
        _clipboardPaths,
        destination: _path,
        move: _clipboardIsCut,
        conflictResolution: resolution,
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
    if (_error == null) clearSelection();
  }

  Future<void> importDroppedFiles(
    List<String> paths, {
    required bool move,
  }) async {
    if (isReadOnly || _locationType != FileManagerLocationType.local) return;
    final destination = p.normalize(_path);
    final sources = paths
        .map(p.normalize)
        .where(
          (source) =>
              !move ||
              (!p.equals(p.dirname(source), destination) &&
                  !p.equals(source, destination)),
        )
        .where((source) => !p.isWithin(source, destination))
        .toSet()
        .toList();
    await _runLocalOperation(sources, destination: destination, move: move);
  }

  Future<void> _pasteArchiveEntries() async {
    await _runArchiveOperation(FileManagerOperation.copy, () async {
      for (final entry in _archiveClipboardEntries) {
        final handler = _archiveHandlers.firstWhere(
          (candidate) => candidate.supports(entry.archivePath!),
        );
        await handler.extractEntry(
          archivePath: entry.archivePath!,
          entryPath: entry.archiveEntryPath!,
          destinationPath: _path,
        );
      }
      clearClipboard();
    });
  }

  Future<void> _pasteLocalToSmb() async {
    final smb = _smb;
    if (smb == null) return;
    await _runNetworkOperation(
      _clipboardIsCut ? FileManagerOperation.move : FileManagerOperation.copy,
      () async {
        for (final source in _clipboardPaths) {
          try {
            await _copyLocalEntityToSmb(
              smb,
              source,
              _joinRemotePath(_path, p.basename(source)),
            );
            if (_clipboardIsCut) await _deleteLocalEntity(source);
          } catch (error) {
            _recordOperationError(source, error);
          } finally {
            _reportNetworkProgress();
          }
        }
        await refresh();
      },
    );
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
      await _runNetworkOperation(
        _clipboardIsCut ? FileManagerOperation.move : FileManagerOperation.copy,
        () async {
          for (final source in _clipboardPaths) {
            try {
              await _copySmbEntityToLocal(
                smb,
                source,
                p.join(_path, p.basename(source)),
              );
              if (_clipboardIsCut) await _deleteSmbEntity(smb, source);
            } catch (error) {
              _recordOperationError(source, error);
            } finally {
              _reportNetworkProgress();
            }
          }
          await refresh();
        },
      );
    } finally {
      await smb.disconnect();
    }
  }

  Future<void> _pasteSmb() async {
    final smb = _smb;
    if (smb == null) return;
    await _runNetworkOperation(
      _clipboardIsCut ? FileManagerOperation.move : FileManagerOperation.copy,
      () async {
        for (final source in _clipboardPaths) {
          final destination = _joinRemotePath(_path, p.basename(source));
          if (source == destination) continue;
          try {
            if (_clipboardIsCut) {
              await smb.rename(source, destination);
            } else {
              await _copySmbEntity(smb, source, destination);
            }
          } catch (error) {
            _recordOperationError(source, error);
          } finally {
            _reportNetworkProgress();
          }
        }
        await refresh();
      },
    );
  }

  Future<void> _runNetworkOperation(
    FileManagerOperation operation,
    Future<void> Function() action,
  ) async {
    _isLoading = true;
    _error = null;
    _operationErrors.clear();
    _operation = operation;
    _operationCompleted = 0;
    _operationTotal = operation == FileManagerOperation.delete
        ? _selectedPaths.length
        : _clipboardPaths.length;
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
      if (_operationErrors.isNotEmpty) _error = _operationErrors.join('\n');
      notifyListeners();
    }
  }

  void _reportNetworkProgress() {
    _operationCompleted++;
    notifyListeners();
  }

  void _recordOperationError(String path, Object error) {
    _operationErrors.add(
      '${p.basename(path)}: ${error.toString().replaceFirst('Exception: ', '')}',
    );
  }

  Future<void> deleteSelected() async {
    if (_locationType == FileManagerLocationType.local) {
      await _runLocalOperation(_selectedPaths.toList(), delete: true);
      return;
    }
    final selected = _entries
        .where((entry) => _selectedPaths.contains(entry.path))
        .toList();
    await _runNetworkOperation(FileManagerOperation.delete, () async {
      for (final entry in selected) {
        try {
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
        } catch (error) {
          _recordOperationError(entry.name, error);
        } finally {
          _reportNetworkProgress();
        }
      }
      clearSelection();
      await refresh();
    });
  }

  bool canExtract(FileManagerEntry entry) =>
      !isRemote &&
      _archiveHandlers.any((handler) => handler.supports(entry.path));

  bool canBrowseArchive(FileManagerEntry entry) => canExtract(entry);

  Future<List<String>> archiveConflicts(FileManagerEntry entry) async {
    final handler = _archiveHandlers.firstWhere(
      (candidate) => candidate.supports(entry.path),
    );
    if (handler is! ZipArchiveHandler) return const [];
    final destination = p.join(_path, p.basenameWithoutExtension(entry.name));
    final archive = ZipDecoder().decodeStream(InputFileStream(entry.path));
    return archive
        .where((item) => item.isFile)
        .map((item) => p.join(destination, item.name))
        .where((path) => File(path).existsSync())
        .toList();
  }

  Future<void> extractArchive(
    FileManagerEntry entry,
    Future<ArchiveConflictResolution> Function(String path) onConflict,
  ) async {
    if (!canExtract(entry)) return;
    final handler = _archiveHandlers.firstWhere(
      (candidate) => candidate.supports(entry.path),
    );
    await _runArchiveOperation(FileManagerOperation.extract, () {
      return handler.extract(
        archivePath: entry.path,
        destinationPath: p.join(_path, p.basenameWithoutExtension(entry.name)),
        onConflict: onConflict,
      );
    });
  }

  Future<void> createZip(String name) async {
    if (isRemote || _selectedPaths.isEmpty) return;
    final sources = _selectedPaths.toList();
    final destination = p.join(
      _path,
      name.endsWith('.zip') ? name : '$name.zip',
    );
    await _runZipOperation(sources, uniqueArchivePath(destination));
  }

  Future<void> _runZipOperation(
    List<String> sources,
    String destination,
  ) async {
    _isLoading = true;
    _error = null;
    _operation = FileManagerOperation.compress;
    _operationCompleted = 0;
    _operationTotal = 0;
    clearSelection();
    notifyListeners();
    final port = ReceivePort();
    try {
      await Isolate.spawn(runZipOperation, {
        'sendPort': port.sendPort,
        'sources': sources,
        'destination': destination,
      });
      await for (final message in port) {
        final data = message as Map<Object?, Object?>;
        if (data['type'] == 'progress') {
          _operationCompleted = data['completed']! as int;
          _operationTotal = data['total']! as int;
          notifyListeners();
        } else if (data['type'] == 'prepared') {
          _operationTotal = data['total']! as int;
          notifyListeners();
        } else if (data['type'] == 'error') {
          _error = data['message']! as String;
        } else {
          break;
        }
      }
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      port.close();
      await refresh();
      _isLoading = false;
      _operation = null;
      _operationCompleted = 0;
      _operationTotal = 0;
      notifyListeners();
    }
  }

  Future<void> _runArchiveOperation(
    FileManagerOperation operation,
    Future<void> Function() action,
  ) async {
    _isLoading = true;
    _error = null;
    _operation = operation;
    notifyListeners();
    try {
      await action();
      clearSelection();
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
      debugPrint('[FileManagerState] Archive operation failed: $error');
    } finally {
      await refresh();
      _isLoading = false;
      _operation = null;
      notifyListeners();
    }
  }

  Future<void> _runLocalOperation(
    List<String> sources, {
    String destination = '',
    bool move = false,
    bool delete = false,
    FileManagerConflictResolution conflictResolution =
        FileManagerConflictResolution.keepBoth,
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
    String? operationError;
    try {
      await Isolate.spawn(runFileManagerOperation, {
        'sendPort': port.sendPort,
        'sources': sources,
        'destination': destination,
        'move': move,
        'delete': delete,
        'overwrite':
            conflictResolution == FileManagerConflictResolution.overwrite,
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
          operationError = operationError == null
              ? data['message']! as String
              : '$operationError\n${data['message']! as String}';
        } else {
          break;
        }
      }
      if (operationError == null) clearSelection();
    } catch (error) {
      operationError = error.toString().replaceFirst('Exception: ', '');
    } finally {
      port.close();
      await refresh();
      _error = operationError;
      _isLoading = false;
      _operationCompleted = 0;
      _operationTotal = 0;
      _operation = null;
      await lease.release();
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (isArchiveBrowsing) return _loadArchiveEntries();
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

  /// Flips the current folder between name and modified-date order without
  /// touching the persisted sort setting.
  void toggleSortField() {
    _sortOverride = activeSortField == FileManagerSortField.modified
        ? FileManagerSortField.name
        : FileManagerSortField.modified;
    _sortOverridePath = path;
    _entries.sort(_compareEntries);
    notifyListeners();
  }

  /// Drops the folder-local sort so re-entering the tool starts from the
  /// persisted setting. Silent — the listeners are going away.
  void clearSortOverride() {
    _sortOverride = null;
    _sortOverridePath = null;
  }

  /// Frees everything tied to the open folder when the tool page goes away. The
  /// state itself is app-scoped, so without this a remote session stays open and
  /// a large listing stays resident for the rest of the app run. Silent, since
  /// the listeners are being torn down; `initialize()` rebuilds all of it.
  Future<void> releaseOnExit() async {
    clearSortOverride();
    _clearEntryLoaders();
    _listing++;
    _isLoading = false;
    _entries = [];
    _selectedPaths.clear();
    _isSelectionMode = false;
    _archivePath = null;
    _archiveDirectory = '';
    _locationType = FileManagerLocationType.local;
    _connection = null;
    _error = null;
    await _disconnectRemote();
  }

  Future<void> updateSort(FileManagerSortField field, bool ascending) async {
    _sortOverride = null;
    _sortOverridePath = null;
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

  Future<void> updateFoldersFirst(bool foldersFirst) async {
    _foldersFirst = foldersFirst;
    _entries.sort(_compareEntries);
    await DatabaseService.instance.setSetting(
      FileManagerTool.config.id,
      _foldersFirstKey,
      foldersFirst.toString(),
    );
    notifyListeners();
  }

  Future<void> updateStartupPath(String? path) async {
    _startupPath = path;
    if (path == null) {
      await DatabaseService.instance.deleteSetting(
        FileManagerTool.config.id,
        _startupPathKey,
      );
    } else {
      await DatabaseService.instance.setSetting(
        FileManagerTool.config.id,
        _startupPathKey,
        path,
      );
    }
    notifyListeners();
  }

  Future<void> updateOpenTool(
    FileManagerOpenCategory category,
    String? toolId,
  ) async {
    _openToolIds[category] = toolId;
    final key = '$_openToolPrefix${category.name}';
    if (toolId == null) {
      await DatabaseService.instance.deleteSetting(
        FileManagerTool.config.id,
        key,
      );
    } else {
      await DatabaseService.instance.setSetting(
        FileManagerTool.config.id,
        key,
        toolId,
      );
    }
    notifyListeners();
  }

  FileManagerOpenCategory? openCategoryForMime(String mimeType) =>
      switch (mimeType) {
        _ when MimeTypeHelper.isUndecodableImage(mimeType) => null,
        _ when mimeType.startsWith('image/') => FileManagerOpenCategory.images,
        'application/pdf' => FileManagerOpenCategory.pdf,
        _ when mimeType.startsWith('audio/') => FileManagerOpenCategory.audio,
        _ when mimeType.startsWith('video/') => FileManagerOpenCategory.video,
        'text/markdown' ||
        'text/x-markdown' => FileManagerOpenCategory.markdown,
        _ => null,
      };

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

  @override
  void dispose() {
    _clearEntryLoaders();
    _emptyMetadata.dispose();
    _emptyChildCount.dispose();
    super.dispose();
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
    var isDirectory = entity is Directory;
    var entryPath = entity.path;
    var isBrokenLink = false;
    if (entity is Link) {
      // Windows junctions (profile compatibility folders, OneDrive redirects)
      // list as links. Let the OS follow the link rather than trusting
      // resolveSymbolicLinks, which an ACL may deny even when traversal works.
      final targetType = await FileSystemEntity.type(entity.path);
      isDirectory = targetType == FileSystemEntityType.directory;
      isBrokenLink = targetType == FileSystemEntityType.notFound;
      if (isDirectory) {
        try {
          final resolvedPath = await entity.resolveSymbolicLinks();
          if (await Directory(resolvedPath).exists()) entryPath = resolvedPath;
        } catch (_) {
          // Traversing the junction path itself still works.
        }
      }
    }
    return FileManagerEntry(
      name: p.basename(entity.path),
      path: entryPath,
      isDirectory: isDirectory,
      isBrokenLink: isBrokenLink,
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
    if (_foldersFirst && a.isDirectory != b.isDirectory) {
      return a.isDirectory ? -1 : 1;
    }
    final comparison = switch (activeSortField) {
      FileManagerSortField.name => a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      ),
      FileManagerSortField.modified => (a.modified ?? DateTime(0)).compareTo(
        b.modified ?? DateTime(0),
      ),
      FileManagerSortField.size => (a.size ?? 0).compareTo(b.size ?? 0),
    };
    if (comparison != 0) return activeSortAscending ? comparison : -comparison;
    // Keeps the order stable (and alphabetical) while metadata is still missing.
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
