import 'dart:io';

import 'package:flutter/services.dart';

class FileManagerStorageAccess {
  FileManagerStorageAccess._();

  static const _channel = MethodChannel('de.renier.tool_lab/storage_access');

  static bool get isAndroid => Platform.isAndroid;

  static Future<bool> hasAllFilesAccess() async {
    if (!Platform.isAndroid) return true;
    return (await _channel.invokeMethod<bool>('hasAllFilesAccess')) ?? false;
  }

  static Future<void> requestAllFilesAccess() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('requestAllFilesAccess');
  }

  static Future<String?> externalStoragePath() async {
    if (!Platform.isAndroid) return null;
    return _channel.invokeMethod<String>('externalStoragePath');
  }
}
