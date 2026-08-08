import 'dart:async';
import 'package:tool_lab/helpers/debug_log.dart';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/helpers/mime_type_helper.dart';

class StringResult {
  final int offset;
  final String text;

  const StringResult(this.offset, this.text);
}

class HexBufferManager {
  final String filePath;
  final int totalSize;
  final Map<int, int> modifications = {};

  Future<void> _lock = Future.value();

  HexBufferManager(this.filePath, this.totalSize);

  Future<void> init() async {}
  Future<void> dispose() async {}

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final previous = _lock;
    final completer = Completer<void>();
    _lock = completer.future;
    return previous
        .then((_) => action())
        .whenComplete(() => completer.complete());
  }

  Future<int> getByte(int offset) async {
    return _synchronized(() async {
      if (modifications.containsKey(offset)) {
        return modifications[offset]!;
      }
      final file = File(filePath);
      final raf = await file.open(mode: FileMode.read);
      try {
        await raf.setPosition(offset);
        return await raf.readByte();
      } finally {
        await raf.close();
      }
    });
  }

  void setByte(int offset, int value) {
    modifications[offset] = value;
  }

  Future<Uint8List> getRange(int offset, int length) async {
    return _synchronized(() async {
      final file = File(filePath);
      final raf = await file.open(mode: FileMode.read);
      try {
        await raf.setPosition(offset);
        final bytes = await raf.read(length);

        for (final entry in modifications.entries) {
          final modOffset = entry.key;
          if (modOffset >= offset && modOffset < offset + length) {
            bytes[modOffset - offset] = entry.value;
          }
        }
        return bytes;
      } finally {
        await raf.close();
      }
    });
  }

  bool get hasModifications => modifications.isNotEmpty;

  void resetModifications() {
    modifications.clear();
  }

  Future<int> find(
    Uint8List pattern, {
    int startOffset = 0,
    bool ignoreCase = false,
  }) async {
    if (pattern.isEmpty || startOffset >= totalSize) return -1;

    int currentOffset = startOffset;
    const int searchChunkSize = 256 * 1024; // 256KB

    while (currentOffset < totalSize) {
      final readSize = min(searchChunkSize, totalSize - currentOffset);
      final chunk = await getRange(currentOffset, readSize);

      for (int i = 0; i <= chunk.length - pattern.length; i++) {
        bool match = true;
        for (int j = 0; j < pattern.length; j++) {
          final b1 = chunk[i + j];
          final b2 = pattern[j];

          if (b1 == b2) continue;

          if (ignoreCase) {
            final isAlpha1 = (b1 >= 65 && b1 <= 90) || (b1 >= 97 && b1 <= 122);
            final isAlpha2 = (b2 >= 65 && b2 <= 90) || (b2 >= 97 && b2 <= 122);
            if (isAlpha1 && isAlpha2 && (b1 ^ 32) == b2) {
              continue;
            }
          }

          match = false;
          break;
        }
        if (match) return currentOffset + i;
      }

      final advance = readSize - pattern.length + 1;
      if (advance <= 0) break;
      currentOffset += advance;
      // Yield to prevent thread blocking during intensive searches
      await Future.delayed(Duration.zero);
    }
    return -1;
  }
}

class HexEditorState extends ChangeNotifier {
  HexBufferManager? _bufferManager;
  String? _filePath;
  String? _fileName;
  int _totalSize = 0;
  String _fileMimeType = 'application/octet-stream';

  final Map<int, Uint8List> _rowCache = {};
  final Set<int> _pendingPages = {};
  static const int pageSize = 128; // rows

  int? _selectedOffset;
  String _searchQuery = '';
  String _searchType = 'hex'; // 'hex' or 'text'
  int? _searchMatchOffset;
  int? _searchMatchLength;

  bool _showAscii = true;

  // Strings scan state
  bool _isScanningStrings = false;
  double _scanProgress = 0.0;
  final List<StringResult> _stringsResults = [];
  bool _scanAborted = false;

  HexBufferManager? get bufferManager => _bufferManager;
  String? get filePath => _filePath;
  String? get fileName => _fileName;
  int get totalSize => _totalSize;
  String get fileMimeType => _fileMimeType;

  int? get selectedOffset => _selectedOffset;
  String get searchQuery => _searchQuery;
  String get searchType => _searchType;
  int? get searchMatchOffset => _searchMatchOffset;
  int? get searchMatchLength => _searchMatchLength;

  bool get showAscii => _showAscii;

  bool get isScanningStrings => _isScanningStrings;
  double get scanProgress => _scanProgress;
  List<StringResult> get stringsResults => _stringsResults;

  bool get hasModifications => _bufferManager?.hasModifications ?? false;

  void toggleAscii(bool value) {
    _showAscii = value;
    notifyListeners();
  }

  void setSelectedOffset(int? offset) {
    _selectedOffset = offset;
    notifyListeners();
  }

  Future<void> loadFile(String path, String name) async {
    await closeFile();

    _filePath = path;
    _fileName = name;

    final file = File(path);
    if (await file.exists()) {
      _totalSize = await file.length();
      _bufferManager = HexBufferManager(path, _totalSize);
      await _bufferManager!.init();

      final previewBytes = await _bufferManager!.getRange(
        0,
        min(64, _totalSize),
      );
      _fileMimeType = MimeTypeHelper.getMimeType(path, bytes: previewBytes);
    }

    _selectedOffset = 0;
    _rowCache.clear();
    _pendingPages.clear();
    _searchQuery = '';
    _searchMatchOffset = null;
    _searchMatchLength = null;
    _stringsResults.clear();
    _isScanningStrings = false;

    notifyListeners();
  }

  Future<void> closeFile() async {
    await _bufferManager?.dispose();
    _bufferManager = null;
    _filePath = null;
    _fileName = null;
    _totalSize = 0;
    _fileMimeType = 'application/octet-stream';
    _selectedOffset = null;
    _rowCache.clear();
    _pendingPages.clear();
    _searchQuery = '';
    _searchMatchOffset = null;
    _searchMatchLength = null;
    _stringsResults.clear();
    _isScanningStrings = false;
    notifyListeners();
  }

  Uint8List? getCachedRow(int rowIndex) {
    final cached = _rowCache[rowIndex];
    if (cached != null) return cached;

    final pageIndex = rowIndex ~/ pageSize;
    if (!_pendingPages.contains(pageIndex)) {
      _pendingPages.add(pageIndex);
      _loadPage(pageIndex);
    }
    return null;
  }

  Future<void> _loadPage(int pageIndex) async {
    if (_bufferManager == null) return;

    // Cache eviction policy: if cache exceeds limit, clear it to avoid memory accumulation
    if (_rowCache.length > 2000) {
      _rowCache.clear();
    }

    final startRow = pageIndex * pageSize;
    final startOffset = startRow * 16;
    final bytesToRead = min(pageSize * 16, _totalSize - startOffset);

    if (bytesToRead <= 0) return;

    try {
      final bytes = await _bufferManager!.getRange(startOffset, bytesToRead);

      for (int i = 0; i < pageSize; i++) {
        final rIndex = startRow + i;
        final byteStart = i * 16;
        if (byteStart < bytes.length) {
          final byteEnd = min(byteStart + 16, bytes.length);
          _rowCache[rIndex] = bytes.sublist(byteStart, byteEnd);
        } else {
          break;
        }
      }
    } catch (e) {
      errorLog('[HexEditorState] Failed to load page $pageIndex: $e');
    } finally {
      _pendingPages.remove(pageIndex);
      notifyListeners();
    }
  }

  void setByte(int offset, int value) {
    if (_bufferManager == null) return;
    _bufferManager!.setByte(offset, value);

    final rowIndex = offset ~/ 16;
    final byteIndex = offset % 16;
    final rowBytes = _rowCache[rowIndex];
    if (rowBytes != null && byteIndex < rowBytes.length) {
      final newBytes = Uint8List.fromList(rowBytes);
      newBytes[byteIndex] = value;
      _rowCache[rowIndex] = newBytes;
    }

    notifyListeners();
  }

  Future<bool> search(String query, String type, {bool next = false}) async {
    if (_bufferManager == null || query.isEmpty) return false;

    _searchQuery = query;
    _searchType = type;

    Uint8List pattern;
    if (type == 'hex') {
      final hex = query.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
      if (hex.length % 2 != 0 || hex.isEmpty) {
        return false;
      }
      final list = <int>[];
      for (int i = 0; i < hex.length; i += 2) {
        list.add(int.parse(hex.substring(i, i + 2), radix: 16));
      }
      pattern = Uint8List.fromList(list);
    } else {
      pattern = Uint8List.fromList(query.codeUnits);
    }

    final startAt = next ? ((_selectedOffset ?? 0) + 1) : 0;
    final result = await _bufferManager!.find(
      pattern,
      startOffset: startAt,
      ignoreCase: type == 'text',
    );

    if (result != -1) {
      _searchMatchOffset = result;
      _searchMatchLength = pattern.length;
      _selectedOffset = result;
      notifyListeners();
      return true;
    } else if (startAt > 0) {
      // Wrap around search
      final wrapResult = await _bufferManager!.find(
        pattern,
        startOffset: 0,
        ignoreCase: type == 'text',
      );
      if (wrapResult != -1) {
        _searchMatchOffset = wrapResult;
        _searchMatchLength = pattern.length;
        _selectedOffset = wrapResult;
        notifyListeners();
        return true;
      }
    }

    _searchMatchOffset = null;
    _searchMatchLength = null;
    notifyListeners();
    return false;
  }

  void clearSearch() {
    _searchQuery = '';
    _searchMatchOffset = null;
    _searchMatchLength = null;
    notifyListeners();
  }

  Future<void> scanForStrings(int minLen) async {
    if (_bufferManager == null || _isScanningStrings) return;

    _isScanningStrings = true;
    _scanProgress = 0.0;
    _stringsResults.clear();
    _scanAborted = false;
    notifyListeners();

    final total = _totalSize;
    const chunkSize = 256 * 1024; // 256KB
    int offset = 0;
    Uint8List carry = Uint8List(0);

    bool isPrintable(int b) => (b >= 32 && b <= 126) || b == 9;

    try {
      while (offset < total && !_scanAborted) {
        final readSize = min(chunkSize, total - offset);
        final chunk = await _bufferManager!.getRange(offset, readSize);

        final bytes = Uint8List(carry.length + chunk.length);
        bytes.setRange(0, carry.length, carry);
        bytes.setRange(carry.length, bytes.length, chunk);

        int seqStart = -1;
        int i = 0;
        for (; i < bytes.length; i++) {
          if (_scanAborted) break;
          final b = bytes[i];
          if (isPrintable(b)) {
            if (seqStart == -1) seqStart = i;
          } else {
            if (seqStart != -1) {
              final len = i - seqStart;
              if (len >= minLen) {
                final slice = bytes.sublist(seqStart, i);
                final s = String.fromCharCodes(slice);
                final globalOffset = offset - carry.length + seqStart;
                _stringsResults.add(StringResult(globalOffset, s));
              }
            }
            seqStart = -1;
          }
        }

        if (seqStart != -1) {
          const maxCarry = 1024 * 1024;
          if (bytes.length - seqStart > maxCarry) {
            final flushEnd = bytes.length - maxCarry;
            final slice = bytes.sublist(seqStart, flushEnd);
            final s = String.fromCharCodes(slice);
            _stringsResults.add(
              StringResult(offset - carry.length + seqStart, s),
            );
            seqStart = flushEnd;
          }
          carry = bytes.sublist(seqStart);
        } else {
          carry = Uint8List(0);
        }

        offset += readSize;
        _scanProgress = min(offset, total) / total;
        notifyListeners();

        await Future.delayed(Duration.zero);
      }

      if (!_scanAborted && carry.length >= minLen) {
        final s = String.fromCharCodes(carry);
        _stringsResults.add(StringResult(total - carry.length, s));
      }
    } catch (e) {
      errorLog('[HexEditorState] Error scanning for strings: $e');
    } finally {
      _isScanningStrings = false;
      notifyListeners();
    }
  }

  void cancelScan() {
    _scanAborted = true;
    _isScanningStrings = false;
    notifyListeners();
  }

  Future<void> exportFile(BuildContext context, TempFileScope scope) async {
    if (_bufferManager == null || _filePath == null) return;

    try {
      final tempPath = await scope.createFile(
        'modified_${_fileName ?? 'file'}',
      );
      final tempFile = File(tempPath);

      final original = File(_filePath!);
      await original.copy(tempPath);

      final raf = await tempFile.open(mode: FileMode.writeOnly);
      for (final entry in _bufferManager!.modifications.entries) {
        await raf.setPosition(entry.key);
        await raf.writeByte(entry.value);
      }
      await raf.close();

      if (context.mounted) {
        await FileSaveHelper.saveFileFromPath(
          context: context,
          sourcePath: tempPath,
          suggestedName: _fileName ?? 'export.bin',
        );
      }
    } catch (e) {
      errorLog('[HexEditorState] Export failed: $e');
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.hexEditorExportFailed(e.toString()))),
        );
      }
    }
  }

  @override
  void dispose() {
    closeFile();
    super.dispose();
  }
}
