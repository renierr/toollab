import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';

class TodoLaunchIntent {
  final String? taskId;
  final bool quickAdd;
  final String? listId;

  const TodoLaunchIntent({this.taskId, this.quickAdd = false, this.listId});

  static TodoLaunchIntent? fromChannel(Object? raw) {
    if (raw is! Map) return null;
    final intent = TodoLaunchIntent(
      taskId: raw['taskId'] as String?,
      quickAdd: raw['quickAdd'] as bool? ?? false,
      listId: raw['listId'] as String?,
    );
    return intent.taskId == null && !intent.quickAdd && intent.listId == null
        ? null
        : intent;
  }
}

class TodoPendingAction {
  final String type;
  final String taskId;
  final int at;

  const TodoPendingAction({
    required this.type,
    required this.taskId,
    required this.at,
  });
}

class TodoPermissionStatus {
  final bool notifications;
  final bool exactAlarms;
  final bool fullScreen;

  const TodoPermissionStatus({
    this.notifications = true,
    this.exactAlarms = true,
    this.fullScreen = true,
  });

  bool get allGranted => notifications && exactAlarms && fullScreen;
}

/// File + channel bridge to the native reminder, alarm and widget layer.
/// The files are the contract; the channel only nudges native to re-read them,
/// so a headless background run can still update them.
class TodoNative {
  TodoNative._();

  static const MethodChannel _channel = MethodChannel(
    'de.renier.tool_lab/todo',
  );
  static const MethodChannel _desktopChannel = MethodChannel(
    'de.renier.tool_lab/todo_desktop',
  );

  static const String alarmsFile = 'alarms.json';
  static const String snoozesFile = 'snoozes.json';
  static const String widgetFile = 'widget.json';
  static const String actionsFile = 'pending_actions.jsonl';

  static void Function(TodoLaunchIntent intent)? onLaunchIntent;
  static void Function()? onActionsPending;
  static bool _handlerSet = false;

  static void ensureHandler() {
    if (_handlerSet || !Platform.isAndroid) return;
    _handlerSet = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'launchIntent':
          final intent = TodoLaunchIntent.fromChannel(call.arguments);
          if (intent != null) onLaunchIntent?.call(intent);
        case 'actionsPending':
          onActionsPending?.call();
      }
      return null;
    });
  }

  static Future<Directory> directory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'todo'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// The `entries` array of an alarm file; empty when missing or unreadable.
  static Future<List<Map<String, dynamic>>> readEntries(String name) async {
    try {
      final file = File(p.join((await directory()).path, name));
      if (!await file.exists()) return const [];
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return [
        for (final e in json['entries'] as List? ?? const [])
          if (e is Map<String, dynamic>) e,
      ];
    } catch (e) {
      errorLog('[TodoNative] reading $name failed: $e');
      return const [];
    }
  }

  static Future<void> writeJson(String name, Object json) async {
    final dir = await directory();
    final tmp = File(p.join(dir.path, '$name.tmp'));
    await tmp.writeAsString(jsonEncode(json), flush: true);
    await tmp.rename(p.join(dir.path, name));
  }

  static Future<List<TodoPendingAction>> drainActions() async {
    final dir = await directory();
    final source = File(p.join(dir.path, actionsFile));
    final draining = File(p.join(dir.path, '$actionsFile.draining'));
    final actions = <TodoPendingAction>[];
    try {
      // A leftover from a run that died mid-drain is applied first.
      if (await source.exists() && !await draining.exists()) {
        await source.rename(draining.path);
      }
      if (!await draining.exists()) return actions;
      for (final line in await draining.readAsLines()) {
        if (line.trim().isEmpty) continue;
        try {
          final map = jsonDecode(line) as Map<String, dynamic>;
          final taskId = map['taskId'] as String?;
          if (taskId == null) continue;
          actions.add(
            TodoPendingAction(
              type: map['type'] as String? ?? '',
              taskId: taskId,
              at: map['at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
            ),
          );
        } catch (_) {}
      }
      await draining.delete();
    } catch (e) {
      errorLog('[TodoNative] drainActions failed: $e');
    }
    return actions;
  }

  static Future<void> reschedule() => _invoke('reschedule');

  static Future<void> refreshWidgets() => _invoke('refreshWidgets');

  static Future<void> cancelNotifications(String taskId) =>
      _invoke('cancelNotifications', {'taskId': taskId});

  static Future<void> openExactAlarmSettings() =>
      _invoke('openExactAlarmSettings');

  static Future<void> openFullScreenSettings() =>
      _invoke('openFullScreenSettings');

  static Future<void> openNotificationSettings() =>
      _invoke('openNotificationSettings');

  /// Sound and vibration of loud alarms live in the system channel settings.
  static Future<void> openAlarmChannelSettings() =>
      _invoke('openAlarmChannelSettings');

  static Future<TodoLaunchIntent?> consumeLaunchIntent() async {
    if (!Platform.isAndroid) return null;
    try {
      return TodoLaunchIntent.fromChannel(
        await _channel.invokeMethod<Object?>('consumeLaunchIntent'),
      );
    } catch (e) {
      errorLog('[TodoNative] consumeLaunchIntent failed: $e');
      return null;
    }
  }

  static Future<TodoPermissionStatus> permissionStatus() async {
    if (!Platform.isAndroid) return const TodoPermissionStatus();
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'permissionStatus',
      );
      return TodoPermissionStatus(
        notifications: raw?['notifications'] as bool? ?? true,
        exactAlarms: raw?['exactAlarms'] as bool? ?? true,
        fullScreen: raw?['fullScreen'] as bool? ?? true,
      );
    } catch (e) {
      errorLog('[TodoNative] permissionStatus failed: $e');
      return const TodoPermissionStatus();
    }
  }

  /// Fails silently in a headless engine, where the channel is not registered.
  static Future<void> _invoke(String method, [Object? args]) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      debugLog('[TodoNative] $method: no channel (headless)');
    } catch (e) {
      errorLog('[TodoNative] $method failed: $e');
    }
  }

  static Future<bool> showDesktopNotification(String title, String body) async {
    try {
      if (Platform.isLinux) return await _notifyLinux(title, body);
      if (Platform.isWindows) {
        return await _desktopChannel.invokeMethod<bool>('notify', {
              'title': title,
              'body': body,
            }) ??
            false;
      }
    } catch (e) {
      errorLog('[TodoNative] desktop notification failed: $e');
    }
    return false;
  }

  static Future<bool> _notifyLinux(String title, String body) async {
    final client = DBusClient.session();
    try {
      await client.callMethod(
        destination: 'org.freedesktop.Notifications',
        path: DBusObjectPath('/org/freedesktop/Notifications'),
        interface: 'org.freedesktop.Notifications',
        name: 'Notify',
        values: [
          const DBusString('ToolLab'),
          const DBusUint32(0),
          const DBusString('task-due'),
          DBusString(title),
          DBusString(body),
          DBusArray.string(const []),
          DBusDict.stringVariant({'urgency': const DBusByte(1)}),
          const DBusInt32(-1),
        ],
        replySignature: DBusSignature('u'),
      );
      return true;
    } finally {
      await client.close();
    }
  }
}
