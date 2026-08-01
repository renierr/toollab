import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

void runFileManagerOperation(Map<String, Object> input) async {
  final sendPort = input['sendPort']! as SendPort;
  final sources = (input['sources']! as List<Object>).cast<String>();
  final destination = input['destination']! as String;
  final move = input['move']! as bool;
  final delete = input['delete']! as bool;
  final overwrite = input['overwrite']! as bool;
  try {
    final files = <File>[];
    for (final source in sources) {
      await _collectFiles(await _entityFor(source), files);
    }
    var completed = 0;
    final total = delete ? sources.length : files.length;
    if (delete) {
      for (final source in sources) {
        try {
          await (await _entityFor(source)).delete(recursive: true);
          completed++;
          sendPort.send({
            'type': 'progress',
            'completed': completed,
            'total': total,
          });
        } catch (error) {
          sendPort.send({
            'type': 'error',
            'message': '${p.basename(source)}: $error',
          });
        }
      }
    } else {
      for (final source in sources) {
        try {
          var target = p.join(destination, p.basename(source));
          if (await FileSystemEntity.type(target) !=
              FileSystemEntityType.notFound) {
            if (overwrite) {
              await (await _entityFor(target)).delete(recursive: true);
            } else {
              target = await _availableTarget(target);
            }
          }
          await _copyEntity(await _entityFor(source), target, () {
            completed++;
            sendPort.send({
              'type': 'progress',
              'completed': completed,
              'total': total,
            });
          });
          if (move) {
            await (await _entityFor(source)).delete(recursive: true);
          }
        } catch (error) {
          sendPort.send({
            'type': 'error',
            'message': '${p.basename(source)}: $error',
          });
        }
      }
    }
    sendPort.send({'type': 'complete'});
  } catch (error) {
    sendPort.send({'type': 'error', 'message': error.toString()});
  }
}

Future<String> _availableTarget(String target) async {
  final directory = p.dirname(target);
  final extension = p.extension(target);
  final name = p.basenameWithoutExtension(target);
  for (var index = 1; ; index++) {
    final candidate = p.join(directory, '$name ($index)$extension');
    if (await FileSystemEntity.type(candidate) ==
        FileSystemEntityType.notFound) {
      return candidate;
    }
  }
}

Future<FileSystemEntity> _entityFor(String path) async {
  final type = await FileSystemEntity.type(path, followLinks: false);
  return type == FileSystemEntityType.directory ? Directory(path) : File(path);
}

Future<void> _collectFiles(FileSystemEntity entity, List<File> files) async {
  if (entity is File) {
    files.add(entity);
    return;
  }
  if (entity is Directory) {
    await for (final child in entity.list(followLinks: false)) {
      await _collectFiles(child, files);
    }
  }
}

Future<void> _copyEntity(
  FileSystemEntity entity,
  String target,
  void Function() onFileCopied,
) async {
  if (entity is File) {
    await entity.copy(target);
    onFileCopied();
    return;
  }
  if (entity is Directory) {
    final directory = Directory(target);
    await directory.create(recursive: true);
    await for (final child in entity.list(followLinks: false)) {
      await _copyEntity(
        child,
        p.join(target, p.basename(child.path)),
        onFileCopied,
      );
    }
  }
}
