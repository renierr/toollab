import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/services/database_service.dart';

class SharingService {
  static const _channel = MethodChannel('de.renier.tool_lab/sharing');

  static final SharingService instance = SharingService._();

  static List<String> startupArgs = [];

  final _sharedFileStreamController = StreamController<SharedFile>.broadcast();

  Stream<SharedFile> get onSharedFile => _sharedFileStreamController.stream;

  SharingService._() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onSharedFile') {
      final map = call.arguments as Map?;
      if (map != null) {
        final sharedFile = SharedFile.fromMap(map);
        _sharedFileStreamController.add(sharedFile);
      }
    }
  }

  Future<SharedFile?> getInitialSharedFile() async {
    // 1. Check Windows / Desktop Startup Arguments
    if (startupArgs.isNotEmpty) {
      for (final arg in startupArgs) {
        final file = File(arg);
        try {
          if (await file.exists()) {
            final name = file.path.split(Platform.pathSeparator).last;
            final mimeType = _getMimeType(file.path);
            return SharedFile(path: file.path, name: name, mimeType: mimeType);
          }
        } catch (e) {
          debugPrint('[SharingService] Failed to check startup file: $e');
        }
      }
    }

    // 2. Check Android Initial Shared File
    try {
      final map = await _channel.invokeMethod<Map>('getSharedFile');
      if (map != null) {
        return SharedFile.fromMap(map);
      }
    } catch (e) {
      debugPrint('[SharingService] Failed to get shared file from channel: $e');
    }

    return null;
  }

  List<ToolModel> getMatchingTools(SharedFile file) {
    final mime = file.mimeType.toLowerCase();
    final matching = <ToolModel>[];
    for (final tool in ToolRegistry.all) {
      if (tool.shareTarget != null) {
        for (final pattern in tool.shareTarget!.accept) {
          if (_mimeTypeMatches(mime, pattern.toLowerCase())) {
            matching.add(tool);
            break;
          }
        }
      }
    }
    return matching;
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

  String _getMimeType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      default:
        return 'application/octet-stream';
    }
  }

  Future<String?> getDefaultTool(String mimeType) async {
    try {
      return await DatabaseService.instance.getSetting(
        'sharing_service',
        'default_tool_$mimeType',
      );
    } catch (e) {
      debugPrint('[SharingService] Failed to get default tool: $e');
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
      debugPrint('[SharingService] Failed to set default tool: $e');
    }
  }
}
