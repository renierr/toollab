import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/todo/config.dart';

/// Reminder behaviour that the publisher needs too, so it loads without
/// [TodoState] in a headless background run.
class TodoNotifySettings {
  static const List<int> snoozeOptions = [5, 10, 15, 30, 60];
  static const List<int> repeatOptions = [0, 5, 10, 15, 30, 60];

  static const String _snoozeKey = 'snooze_minutes';
  static const String _repeatKey = 'repeat_minutes';
  static const String _repeatAllKey = 'repeat_all_tasks';
  static const String _digestKey = 'digest_enabled';
  static const String _digestTimeKey = 'digest_time';
  static const String _alarmSoundKey = 'alarm_sound';
  static const String _alarmVibrateKey = 'alarm_vibrate';

  final int snoozeMinutes;

  /// Rings again every this many minutes until done; 0 is off.
  final int repeatMinutes;

  /// Repeat for every task rather than only important ones.
  final bool repeatAll;
  final bool digestEnabled;

  /// Minutes after midnight.
  final int digestMinutes;
  final bool alarmSound;
  final bool alarmVibrate;

  const TodoNotifySettings({
    this.snoozeMinutes = 10,
    this.repeatMinutes = 0,
    this.repeatAll = false,
    this.digestEnabled = false,
    this.digestMinutes = 8 * 60,
    this.alarmSound = true,
    this.alarmVibrate = true,
  });

  bool repeats({required bool important}) =>
      repeatMinutes > 0 && (repeatAll || important);

  TodoNotifySettings copyWith({
    int? snoozeMinutes,
    int? repeatMinutes,
    bool? repeatAll,
    bool? digestEnabled,
    int? digestMinutes,
    bool? alarmSound,
    bool? alarmVibrate,
  }) => TodoNotifySettings(
    snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
    repeatMinutes: repeatMinutes ?? this.repeatMinutes,
    repeatAll: repeatAll ?? this.repeatAll,
    digestEnabled: digestEnabled ?? this.digestEnabled,
    digestMinutes: digestMinutes ?? this.digestMinutes,
    alarmSound: alarmSound ?? this.alarmSound,
    alarmVibrate: alarmVibrate ?? this.alarmVibrate,
  );

  static Future<TodoNotifySettings> load() async {
    final db = DatabaseService.instance;
    final id = TodoTool.config.id;
    int? number(String? raw, int max) {
      final v = int.tryParse(raw ?? '');
      return v == null || v < 0 || v >= max ? null : v;
    }

    const defaults = TodoNotifySettings();
    return TodoNotifySettings(
      snoozeMinutes:
          number(await db.getSetting(id, _snoozeKey), 24 * 60) ??
          defaults.snoozeMinutes,
      repeatMinutes:
          number(await db.getSetting(id, _repeatKey), 24 * 60) ??
          defaults.repeatMinutes,
      repeatAll: await db.getSetting(id, _repeatAllKey) == 'true',
      digestEnabled: await db.getSetting(id, _digestKey) == 'true',
      digestMinutes:
          number(await db.getSetting(id, _digestTimeKey), 24 * 60) ??
          defaults.digestMinutes,
      alarmSound: await db.getSetting(id, _alarmSoundKey) != 'false',
      alarmVibrate: await db.getSetting(id, _alarmVibrateKey) != 'false',
    );
  }

  Future<void> save() async {
    final db = DatabaseService.instance;
    final id = TodoTool.config.id;
    await db.setSetting(id, _snoozeKey, '$snoozeMinutes');
    await db.setSetting(id, _repeatKey, '$repeatMinutes');
    await db.setSetting(id, _repeatAllKey, '$repeatAll');
    await db.setSetting(id, _digestKey, '$digestEnabled');
    await db.setSetting(id, _digestTimeKey, '$digestMinutes');
    await db.setSetting(id, _alarmSoundKey, '$alarmSound');
    await db.setSetting(id, _alarmVibrateKey, '$alarmVibrate');
  }
}
