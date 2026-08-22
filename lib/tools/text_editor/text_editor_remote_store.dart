import 'dart:convert';
import 'dart:io';

import 'package:dart_smb2/dart_smb2.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:path/path.dart' as p;
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/file_manager/config.dart';
import 'package:tool_lab/tools/file_manager/file_manager_connection.dart';
import 'package:tool_lab/tools/file_manager/file_manager_state.dart';

/// Uploads/downloads files against the connection a [SharedFileOrigin] points
/// at, so tools that received a downloaded copy can write changes back.
class TextEditorRemoteStore {
  TextEditorRemoteStore._();

  static const _secureStorage = FlutterSecureStorage();

  static Future<void> upload({
    required SharedFileOrigin origin,
    required String localPath,
  }) async {
    final profile = await _connectionProfile(origin.connectionId);
    if (profile == null) {
      throw Exception('Connection profile no longer exists.');
    }
    final password = await _secureStorage.read(
      key: FileManagerState.passwordKey(origin.connectionId),
    );
    switch (origin.protocol) {
      case 'ftp':
        await _uploadFtp(origin, profile, password, localPath);
      case 'smb':
        await _uploadSmb(origin, profile, password, localPath);
      default:
        throw Exception('Unknown protocol: ${origin.protocol}');
    }
  }

  static Future<void> download({
    required SharedFileOrigin origin,
    required String localPath,
  }) async {
    final profile = await _connectionProfile(origin.connectionId);
    if (profile == null) {
      throw Exception('Connection profile no longer exists.');
    }
    final password = await _secureStorage.read(
      key: FileManagerState.passwordKey(origin.connectionId),
    );
    switch (origin.protocol) {
      case 'ftp':
        await _withFtp(profile, password, (ftp) async {
          final dir = p.posix.dirname(origin.remotePath);
          final name = p.posix.basename(origin.remotePath);
          final changed = dir.isEmpty || dir == '.'
              ? true
              : await ftp.changeDirectory(dir);
          if (!changed) throw Exception('Folder could not be opened.');
          final ok = await ftp.downloadFile(name, File(localPath));
          if (!ok) throw Exception('FTP download failed.');
        });
      case 'smb':
        await _withSmb(profile, password, (smb) async {
          await smb.downloadToFile(origin.remotePath, File(localPath));
        });
      default:
        throw Exception('Unknown protocol: ${origin.protocol}');
    }
  }

  static Future<void> _uploadFtp(
    SharedFileOrigin origin,
    FileManagerConnection profile,
    String? password,
    String localPath,
  ) {
    return _withFtp(profile, password, (ftp) async {
      final dir = p.posix.dirname(origin.remotePath);
      final name = p.posix.basename(origin.remotePath);
      final changed = dir.isEmpty || dir == '.'
          ? true
          : await ftp.changeDirectory(dir);
      if (!changed) throw Exception('Folder could not be opened.');
      final ok = await ftp.uploadFile(File(localPath), sRemoteName: name);
      if (!ok) throw Exception('FTP upload failed.');
    });
  }

  static Future<void> _uploadSmb(
    SharedFileOrigin origin,
    FileManagerConnection profile,
    String? password,
    String localPath,
  ) {
    return _withSmb(profile, password, (smb) async {
      await smb.writeFile(
        origin.remotePath,
        await File(localPath).readAsBytes(),
      );
    });
  }

  static Future<void> _withFtp(
    FileManagerConnection profile,
    String? password,
    Future<void> Function(FTPConnect ftp) action,
  ) async {
    final ftp = FTPConnect(
      profile.host,
      port: profile.port,
      user: profile.username.isEmpty ? 'anonymous' : profile.username,
      pass: password ?? '',
    );
    try {
      await ftp.connect();
      await action(ftp);
    } finally {
      try {
        await ftp.disconnect();
      } catch (error) {
        errorLog('[TextEditorRemoteStore] FTP disconnect failed: $error');
      }
    }
  }

  static Future<void> _withSmb(
    FileManagerConnection profile,
    String? password,
    Future<void> Function(Smb2Pool smb) action,
  ) async {
    if (profile.share.isEmpty) throw Exception('An SMB share is required.');
    final smb = await Smb2Pool.connect(
      host: profile.host,
      share: profile.share,
      user: profile.username,
      password: password ?? '',
    );
    try {
      await action(smb);
    } finally {
      try {
        await smb.disconnect();
      } catch (error) {
        errorLog('[TextEditorRemoteStore] SMB disconnect failed: $error');
      }
    }
  }

  static Future<FileManagerConnection?> _connectionProfile(String id) async {
    final settings = await DatabaseService.instance.getAllSettings(
      FileManagerTool.config.id,
    );
    final source = settings['connections'];
    if (source == null) return null;
    try {
      final list = jsonDecode(source) as List<dynamic>;
      for (final entry in list) {
        final profile = FileManagerConnection.fromJson(
          entry as Map<String, dynamic>,
        );
        if (profile.id == id) return profile;
      }
    } catch (_) {}
    return null;
  }
}
