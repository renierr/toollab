import 'dart:async';
import 'package:tool_lab/helpers/debug_log.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/helpers/mime_type_helper.dart';

class SharingService {
  static const _channel = MethodChannel('de.renier.tool_lab/sharing');

  static final SharingService instance = SharingService._();

  static List<String> startupArgs = [];

  final _sharedFileStreamController = StreamController<SharedFile>.broadcast();
  final _sharedFilesStreamController = StreamController<SharedData>.broadcast();

  Stream<SharedFile> get onSharedFile => _sharedFileStreamController.stream;
  Stream<SharedData> get onSharedData => _sharedFilesStreamController.stream;

  SharingService._() {
    if (Platform.isAndroid) {
      _channel.setMethodCallHandler(_handleMethodCall);
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onSharedFile') {
      final map = call.arguments as Map?;
      if (map != null) {
        final sharedFile = SharedFile.fromMap(map);
        _sharedFileStreamController.add(sharedFile);
        _sharedFilesStreamController.add(SharedData.single(sharedFile));
      }
    } else if (call.method == 'onSharedFiles') {
      final list = call.arguments as List?;
      if (list != null) {
        final files = list
            .map((item) => SharedFile.fromMap(item as Map))
            .toList();
        if (files.isNotEmpty) {
          _sharedFileStreamController.add(files.first);
          _sharedFilesStreamController.add(SharedData(files));
        }
      }
    }
  }

  Future<SharedData?> getInitialSharedData() async {
    // 1. Check Windows / Desktop Startup Arguments
    if (startupArgs.isNotEmpty) {
      final files = <SharedFile>[];
      for (final arg in startupArgs) {
        final file = File(arg);
        try {
          if (await file.exists()) {
            final name = file.path.split(Platform.pathSeparator).last;
            final mimeType = MimeTypeHelper.getMimeType(file.path);
            files.add(
              SharedFile(path: file.path, name: name, mimeType: mimeType),
            );
          }
        } catch (e) {
          errorLog('[SharingService] Failed to check startup file: $e');
        }
      }
      if (files.isNotEmpty) {
        return SharedData(files);
      }
    }

    // 2. Check Android Initial Shared Files
    if (!Platform.isAndroid) return null;
    try {
      final list = await _channel.invokeMethod<List>('getSharedFiles');
      if (list != null && list.isNotEmpty) {
        final files = list
            .map((map) => SharedFile.fromMap(map as Map))
            .toList();
        return SharedData(files);
      }
      // Fallback to single shared file
      final map = await _channel.invokeMethod<Map>('getSharedFile');
      if (map != null) {
        return SharedData.single(SharedFile.fromMap(map));
      }
    } catch (e) {
      errorLog('[SharingService] Failed to get shared files from channel: $e');
    }

    return null;
  }

  Future<SharedFile?> getInitialSharedFile() async {
    final data = await getInitialSharedData();
    return data?.firstFile;
  }

  Future<void> clearSharedData() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('clearSharedFiles');
    } catch (e) {
      errorLog('[SharingService] Failed to clear shared files: $e');
    }
  }

  Future<void> clearSharedFile() async {
    await clearSharedData();
  }

  List<ToolModel> getMatchingTools(SharedFile file) {
    final mime = file.mimeType.toLowerCase();
    final ext = _fileExtension(file.name);
    final matching = <ToolModel>[];
    for (final tool in ToolRegistry.all) {
      if (tool.shareTarget == null) continue;
      final mimeMatch = tool.shareTarget!.accept.any(
        (pattern) => _mimeTypeMatches(mime, pattern.toLowerCase()),
      );
      // Extension match covers files whose resolved MIME does not match a
      // tool's declared accepts (cross-platform MIME resolution is unreliable,
      // e.g. tracker modules resolve to audio/x-mod, not octet-stream).
      final extMatch =
          ext != null && tool.fileExtensions.any((e) => e.toLowerCase() == ext);
      if (mimeMatch || extMatch) matching.add(tool);
    }
    return matching;
  }

  String? _fileExtension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1).toLowerCase();
  }

  bool _mimeTypeMatches(String mime, String pattern) {
    if (mime == pattern) return true;
    if (pattern == '*/*') return true;
    if (pattern.endsWith('/*')) {
      final category = pattern.substring(0, pattern.length - 2);
      if (mime.startsWith('$category/')) return true;
    }
    return false;
  }

  Future<String?> getDefaultTool(String mimeType) async {
    try {
      return await DatabaseService.instance.getSetting(
        'sharing_service',
        'default_tool_$mimeType',
      );
    } catch (e) {
      errorLog('[SharingService] Failed to get default tool: $e');
      return null;
    }
  }

  Future<void> setDefaultTool(String mimeType, String toolId) async {
    try {
      await DatabaseService.instance.setSetting(
        'sharing_service',
        'default_tool_$mimeType',
        toolId,
      );
    } catch (e) {
      errorLog('[SharingService] Failed to set default tool: $e');
    }
  }

  Future<Map<String, String>> getAllDefaultTools() async {
    try {
      final all = await DatabaseService.instance.getAllSettings(
        'sharing_service',
      );
      return {
        for (final entry in all.entries)
          if (entry.key.startsWith('default_tool_'))
            entry.key.substring('default_tool_'.length): entry.value,
      };
    } catch (e) {
      errorLog('[SharingService] Failed to get default tools: $e');
      return {};
    }
  }

  Future<void> clearAllDefaultTools() async {
    try {
      await DatabaseService.instance.deleteAllSettings('sharing_service');
    } catch (e) {
      errorLog('[SharingService] Failed to clear default tools: $e');
    }
  }
}
