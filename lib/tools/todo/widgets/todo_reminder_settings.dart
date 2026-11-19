import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/todo_native.dart';
import 'package:tool_lab/tools/todo/todo_operations.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';

/// Snooze, repeat, alarm sound and the daily summary. Snooze, repeat and
/// sound only exist on Android, where notifications carry actions.
class TodoReminderSettings extends StatelessWidget {
  const TodoReminderSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<TodoState>();
    final settings = state.notifySettings;
    final android = Platform.isAndroid;
    String minutes(int m) => m == 0 ? l10n.todoOff : l10n.todoMinutes(m);
    final digestTime = TimeOfDay(
      hour: settings.digestMinutes ~/ 60,
      minute: settings.digestMinutes % 60,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (android) ...[
          TodoChoiceTile<int>(
            icon: Icons.snooze_outlined,
            title: l10n.todoSnoozeLength,
            subtitle: l10n.todoSnoozeLengthHint,
            value: settings.snoozeMinutes,
            options: {
              for (final m in TodoNotifySettings.snoozeOptions) m: minutes(m),
            },
            onChanged: (m) =>
                state.setNotifySettings(settings.copyWith(snoozeMinutes: m)),
          ),
          TodoChoiceTile<int>(
            icon: Icons.notifications_active_outlined,
            title: l10n.todoRepeatReminders,
            subtitle: l10n.todoRepeatRemindersHint,
            value: settings.repeatMinutes,
            options: {
              for (final m in TodoNotifySettings.repeatOptions) m: minutes(m),
            },
            onChanged: (m) =>
                state.setNotifySettings(settings.copyWith(repeatMinutes: m)),
          ),
          if (settings.repeatMinutes > 0)
            SwitchListTile(
              secondary: const SizedBox(width: 24),
              title: Text(l10n.todoRepeatAllTasks),
              subtitle: Text(l10n.todoRepeatAllTasksHint),
              value: settings.repeatAll,
              onChanged: (v) =>
                  state.setNotifySettings(settings.copyWith(repeatAll: v)),
            ),
          ListTile(
            leading: const Icon(Icons.music_note_outlined),
            title: Text(l10n.todoAlarmSound),
            subtitle: Text(l10n.todoAlarmSoundHint),
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: TodoNative.openAlarmChannelSettings,
          ),
        ],
        SwitchListTile(
          secondary: const Icon(Icons.summarize_outlined),
          title: Text(l10n.todoDigest),
          subtitle: Text(l10n.todoDigestHint),
          value: settings.digestEnabled,
          onChanged: (v) =>
              state.setNotifySettings(settings.copyWith(digestEnabled: v)),
        ),
        if (settings.digestEnabled)
          ListTile(
            leading: const SizedBox(width: 24),
            title: Text(l10n.todoDigestTime),
            trailing: Text(digestTime.format(context)),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: digestTime,
              );
              if (picked == null) return;
              await state.setNotifySettings(
                settings.copyWith(
                  digestMinutes: picked.hour * 60 + picked.minute,
                ),
              );
            },
          ),
      ],
    );
  }
}

class TodoCleanupTile extends StatelessWidget {
  const TodoCleanupTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<TodoState>();
    return TodoChoiceTile<int>(
      icon: Icons.auto_delete_outlined,
      title: l10n.todoCleanup,
      subtitle: l10n.todoCleanupHint,
      value: state.cleanupDays,
      options: {
        for (final d in TodoOperations.cleanupOptions)
          d: d == 0 ? l10n.todoNever : l10n.todoDays(d),
      },
      onChanged: state.setCleanupDays,
    );
  }
}

/// A settings row that picks one of [options] from a popup menu.
class TodoChoiceTile<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  const TodoChoiceTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: title,
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final e in options.entries)
          CheckedPopupMenuItem(
            value: e.key,
            checked: e.key == value,
            child: Text(e.value),
          ),
      ],
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: Text(options[value] ?? '$value'),
      ),
    );
  }
}
