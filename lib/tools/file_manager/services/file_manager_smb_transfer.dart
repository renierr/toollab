import 'dart:io';

import 'package:dart_smb2/dart_smb2.dart';
import 'package:path/path.dart' as p;

/// Recursive entity transfers between local storage and an SMB share.
class FileManagerSmbTransfer {
  FileManagerSmbTransfer._();

  static String joinRemotePath(String parent, String name) =>
      parent.isEmpty ? name : '$parent/$name';

  static Future<void> copySmbEntity(
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
        await copySmbEntity(
          smb,
          joinRemotePath(source, entry.name),
          joinRemotePath(destination, entry.name),
        );
      }
      return;
    }
    await smb.writeFile(destination, await smb.readFile(source));
  }

  static Future<void> copyLocalEntityToSmb(
    Smb2Pool smb,
    String source,
    String destination,
  ) async {
    final type = await FileSystemEntity.type(source, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await smb.mkdir(destination);
      await for (final child in Directory(source).list(followLinks: false)) {
        await copyLocalEntityToSmb(
          smb,
          child.path,
          joinRemotePath(destination, p.basename(child.path)),
        );
      }
      return;
    }
    await smb.writeFile(destination, await File(source).readAsBytes());
  }

  static Future<void> copySmbEntityToLocal(
    Smb2Pool smb,
    String source,
    String destination,
  ) async {
    final stat = await smb.stat(source);
    if (stat.isDirectory) {
      await Directory(destination).create();
      for (final entry in await smb.listDirectory(source)) {
        if (entry.name == '.' || entry.name == '..') continue;
        await copySmbEntityToLocal(
          smb,
          joinRemotePath(source, entry.name),
          p.join(destination, entry.name),
        );
      }
      return;
    }
    await File(destination).writeAsBytes(await smb.readFile(source));
  }

  static Future<void> deleteLocalEntity(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else {
      await File(path).delete();
    }
  }

  static Future<void> deleteSmbEntity(Smb2Pool smb, String path) async {
    final stat = await smb.stat(path);
    if (stat.isDirectory) {
      for (final entry in await smb.listDirectory(path)) {
        if (entry.name == '.' || entry.name == '..') continue;
        await deleteSmbEntity(smb, joinRemotePath(path, entry.name));
      }
      await smb.rmdir(path);
    } else {
      await smb.deleteFile(path);
    }
  }
}
