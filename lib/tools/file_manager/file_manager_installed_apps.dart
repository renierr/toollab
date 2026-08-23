import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/helpers/debug_log.dart';

class FileManagerStorageInfo {
  final int totalBytes;
  final int freeBytes;

  const FileManagerStorageInfo({
    required this.totalBytes,
    required this.freeBytes,
  });

  double get usedFraction =>
      totalBytes <= 0 ? 0 : (totalBytes - freeBytes) / totalBytes;

  factory FileManagerStorageInfo.fromMap(Object? data) {
    final map = Map<Object?, Object?>.from(data! as Map);
    return FileManagerStorageInfo(
      totalBytes: map['totalBytes']! as int,
      freeBytes: map['freeBytes']! as int,
    );
  }
}

class FileManagerAppInfo {
  final String name;
  final String packageName;
  final String version;
  final int sizeBytes;
  final bool isSystem;
  final Uint8List? icon;

  const FileManagerAppInfo({
    required this.name,
    required this.packageName,
    required this.version,
    required this.sizeBytes,
    required this.isSystem,
    required this.icon,
  });

  factory FileManagerAppInfo.fromMap(Object? data) {
    final map = Map<Object?, Object?>.from(data! as Map);
    return FileManagerAppInfo(
      name: map['name']! as String,
      packageName: map['packageName']! as String,
      version: map['version'] as String? ?? '',
      sizeBytes: map['sizeBytes'] as int? ?? 0,
      isSystem: map['isSystem'] as bool? ?? false,
      icon: map['icon'] as Uint8List?,
    );
  }
}

class FileManagerInstalledApps {
  static const _channel = MethodChannel('de.renier.tool_lab/installed_apps');

  static bool get isSupported => Platform.isAndroid;

  static Future<List<FileManagerAppInfo>> list() async {
    if (!isSupported) return const [];
    try {
      final result = await _channel.invokeListMethod<Object?>('list');
      return (result ?? const []).map(FileManagerAppInfo.fromMap).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } on PlatformException catch (error) {
      errorLog('[FileManager] App listing failed: ${error.message}');
      return const [];
    }
  }

  /// Free/total space of the primary storage volume.
  static Future<FileManagerStorageInfo?> storageInfo() {
    if (Platform.isAndroid) return _androidStorageInfo();
    if (Platform.isWindows) return _windowsStorageInfo(Directory.current.path);
    return Future.value(null);
  }

  static Future<FileManagerStorageInfo?> _androidStorageInfo() async {
    try {
      final result = await _channel.invokeMethod<Object?>('storageInfo');
      return result == null ? null : FileManagerStorageInfo.fromMap(result);
    } on PlatformException catch (error) {
      errorLog('[FileManager] Storage info failed: ${error.message}');
      return null;
    }
  }

  static Future<void> openAppSettings(String packageName) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('openAppSettings', packageName);
    } on PlatformException catch (error) {
      errorLog('[FileManager] Open app settings failed: ${error.message}');
    }
  }

  static Future<FileManagerStorageInfo?> _windowsStorageInfo(
    String pathOnVolume,
  ) async {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    // ignore: non_constant_identifier_names
    final GetDiskFreeSpaceExW = kernel32
        .lookupFunction<
          Int32 Function(
            Pointer<Utf16>,
            Pointer<Uint64>,
            Pointer<Uint64>,
            Pointer<Uint64>,
          ),
          int Function(
            Pointer<Utf16>,
            Pointer<Uint64>,
            Pointer<Uint64>,
            Pointer<Uint64>,
          )
        >('GetDiskFreeSpaceExW');
    final directory = pathOnVolume.toNativeUtf16();
    final free = calloc<Uint64>();
    final total = calloc<Uint64>();
    try {
      final ok = GetDiskFreeSpaceExW(directory, free, total, nullptr);
      if (ok == 0) return null;
      return FileManagerStorageInfo(
        totalBytes: total.value,
        freeBytes: free.value,
      );
    } catch (error) {
      errorLog('[FileManager] Disk query failed: $error');
      return null;
    } finally {
      calloc.free(directory);
      calloc.free(free);
      calloc.free(total);
    }
  }
}
