import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'sleep_session_data.dart';
import 'sleep_session_store.dart';

class SleepSyncAliases {
  static File _file(String path) => File('$path/sync_aliases.json');

  static Future<Map<String, dynamic>> _read(String path) async {
    try {
      final value = jsonDecode(await _file(path).readAsString());
      return value is Map<String, dynamic> ? value : {};
    } catch (_) {
      return {};
    }
  }

  static Future<void> verify({
    required SleepSessionData session,
    required SleepEvent event,
    required String alias,
    required String fileName,
    required int updatedAt,
    required List<int> bytes,
  }) async {
    final file = File('${session.path}/${event.fileName}');
    if (!await file.exists()) return;
    if (fileName != event.fileName) {
      throw StateError('Conflicting sleep audio formats for ${session.id}');
    }
    final before = await file.stat();
    if (!listEquals(await file.readAsBytes(), bytes)) {
      throw StateError('Conflicting sleep audio records for ${session.id}');
    }
    final after = await file.stat();
    if (before.size != after.size || before.modified != after.modified) return;
    final entries = await _read(session.path);
    entries[alias] = {
      'version': updatedAt,
      'canonical': event.syncFileName,
      'file': event.fileName,
      'audioVersion':
          event.audioUpdatedAt ?? event.endedAt.millisecondsSinceEpoch,
      'size': after.size,
      'modified': after.modified.microsecondsSinceEpoch,
    };
    await _file(session.path).writeAsString(jsonEncode(entries));
  }

  static Future<bool> verifyOffloaded({
    required SleepSession session,
    required SleepEvent event,
    required String alias,
    required int updatedAt,
    required Map<String, dynamic>? canonical,
    required Map<String, dynamic>? duplicate,
  }) async {
    final version =
        event.audioUpdatedAt ?? event.endedAt.millisecondsSinceEpoch;
    if (session.hasFile(event) ||
        session.offloaded[event.syncFileName] != version) {
      return false;
    }
    final a = canonical?['audio'];
    final b = duplicate?['audio'];
    if (a is! String || b is! String) return false;
    if (canonical?['file'] != event.fileName ||
        duplicate?['file'] != event.fileName ||
        !listEquals(base64Decode(a), base64Decode(b))) {
      throw StateError('Conflicting sleep audio records for ${session.id}');
    }
    final entries = await _read(session.path);
    entries[alias] = {
      'version': updatedAt,
      'canonical': event.syncFileName,
      'file': event.fileName,
      'audioVersion': version,
    };
    await _file(session.path).writeAsString(jsonEncode(entries));
    return true;
  }

  static Future<Set<String>> verified(
    SleepSession session,
    Map<String, int> candidates,
  ) async {
    final entries = await _read(session.path);
    final verified = <String>{};
    for (final event in session.data.events) {
      for (final candidate in candidates.entries) {
        final entry = entries[candidate.key];
        if (entry is! Map ||
            entry['version'] != candidate.value ||
            entry['canonical'] != event.syncFileName ||
            entry['file'] != event.fileName ||
            entry['audioVersion'] !=
                (event.audioUpdatedAt ??
                    event.endedAt.millisecondsSinceEpoch)) {
          continue;
        }
        final file = File('${session.path}/${event.fileName}');
        if (await file.exists()) {
          final stat = await file.stat();
          if (stat.size != entry['size'] ||
              stat.modified.microsecondsSinceEpoch != entry['modified']) {
            continue;
          }
        } else if (session.offloaded[event.syncFileName] !=
            entry['audioVersion']) {
          continue;
        }
        verified.add(candidate.key);
      }
    }
    return verified;
  }
}
