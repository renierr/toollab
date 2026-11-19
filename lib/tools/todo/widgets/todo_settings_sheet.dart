import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/background_task_service.dart';
import 'package:tool_lab/tools/todo/todo_background.dart';
import 'package:tool_lab/tools/todo/todo_native.dart';
import 'package:tool_lab/widgets/background_task_tile.dart';

/// Reminder permissions, background refresh and the quick-add syntax.
class TodoSettingsSheet extends StatefulWidget {
  const TodoSettingsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const TodoSettingsSheet(),
  );

  @override
  State<TodoSettingsSheet> createState() => _TodoSettingsSheetState();
}

class _TodoSettingsSheetState extends State<TodoSettingsSheet>
    with DisposeCleanup, WidgetsBindingObserver {
  TodoPermissionStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    onDispose(() => WidgetsBinding.instance.removeObserver(this));
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final status = await TodoNative.permissionStatus();
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = _status;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(l10n.todoSettings, style: theme.textTheme.titleLarge),
            ),
            if (Platform.isAndroid && status != null) ...[
              _PermissionTile(
                icon: Icons.notifications_outlined,
                title: l10n.todoPermissionNotifications,
                granted: status.notifications,
                onTap: TodoNative.openNotificationSettings,
              ),
              _PermissionTile(
                icon: Icons.schedule,
                title: l10n.todoPermissionExact,
                granted: status.exactAlarms,
                onTap: TodoNative.openExactAlarmSettings,
              ),
              _PermissionTile(
                icon: Icons.alarm,
                title: l10n.todoPermissionFullScreen,
                granted: status.fullScreen,
                onTap: TodoNative.openFullScreenSettings,
              ),
              const Divider(),
            ],
            if (BackgroundTaskService.isSupported)
              BackgroundTaskTile(
                task: TodoBackground.task,
                icon: Icons.sync_outlined,
                title: l10n.todoBackgroundTitle,
                description: l10n.todoBackgroundSubtitle,
              ),
            if (!Platform.isAndroid)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.todoDesktopRemindersTitle),
                subtitle: Text(l10n.todoDesktopRemindersSubtitle),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bolt_outlined),
              title: Text(l10n.todoQuickAddHelpTitle),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l10n.todoQuickAddHelp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool granted;
  final VoidCallback onTap;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.granted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        granted ? l10n.todoPermissionGranted : l10n.todoPermissionMissing,
      ),
      trailing: Icon(
        granted ? Icons.check_circle : Icons.error_outline,
        color: granted ? scheme.primary : scheme.error,
      ),
      onTap: onTap,
    );
  }
}
