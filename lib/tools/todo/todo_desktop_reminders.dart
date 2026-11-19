import 'dart:async';
import 'dart:io';

import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/todo/config.dart';
import 'package:tool_lab/tools/todo/todo_db_helper.dart';
import 'package:tool_lab/tools/todo/todo_native.dart';
import 'package:tool_lab/tools/todo/todo_publisher.dart';

/// Reminders on Linux and Windows: one timer to the next entry while the app
/// runs. Missed ones (app was closed) fire once on the next start.
class TodoDesktopReminders {
  TodoDesktopReminders._();
  static final TodoDesktopReminders instance = TodoDesktopReminders._();

  static const String _lastFiredKey = 'desktop_last_fired';

  Timer? _timer;
  bool _started = false;
  int _lastFired = 0;

  static bool get isSupported => Platform.isLinux || Platform.isWindows;

  Future<void> start() async {
    if (_started || !isSupported) return;
    _started = true;
    final stored = await DatabaseService.instance.getSetting(
      TodoTool.config.id,
      _lastFiredKey,
    );
    _lastFired =
        int.tryParse(stored ?? '') ?? DateTime.now().millisecondsSinceEpoch;
    await refresh();
  }

  Future<void> refresh() async {
    if (!_started) return;
    _timer?.cancel();
    try {
      final db = TodoDbHelper.instance;
      final lists = {for (final l in await db.getLists()) l.shortId: l};
      final l10n = await TodoPublisher.localizations();
      final now = DateTime.now();
      var from = DateTime.fromMillisecondsSinceEpoch(_lastFired);
      if (from.isAfter(now)) from = now;
      final entries = TodoPublisher.buildEntries(
        await db.getTasks(),
        lists,
        l10n,
        now: from,
        window: now.difference(from) + const Duration(days: 2),
      ).where((e) => e.at > _lastFired).toList();
      final due = entries.where((e) => e.at <= now.millisecondsSinceEpoch);
      for (final entry in due) {
        await TodoNative.showDesktopNotification(entry.title, entry.body);
      }
      if (due.isNotEmpty) await _markFired(now.millisecondsSinceEpoch);
      final next = entries
          .where((e) => e.at > now.millisecondsSinceEpoch)
          .firstOrNull;
      if (next == null) {
        _timer = Timer(const Duration(hours: 12), refresh);
        return;
      }
      final wait = Duration(milliseconds: next.at - now.millisecondsSinceEpoch);
      _timer = Timer(
        wait > const Duration(hours: 12) ? const Duration(hours: 12) : wait,
        refresh,
      );
    } catch (e) {
      errorLog('[TodoDesktopReminders] refresh failed: $e');
      _timer = Timer(const Duration(minutes: 5), refresh);
    }
  }

  Future<void> _markFired(int at) async {
    _lastFired = at;
    await DatabaseService.instance.setSetting(
      TodoTool.config.id,
      _lastFiredKey,
      '$at',
    );
  }
}
