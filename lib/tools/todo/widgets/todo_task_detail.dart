import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_colors.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';
import 'package:tool_lab/tools/todo/widgets/todo_attachments_section.dart';
import 'package:tool_lab/tools/todo/widgets/todo_check_circle.dart';
import 'package:tool_lab/tools/todo/widgets/todo_edit_field.dart';
import 'package:tool_lab/tools/todo/widgets/todo_meta_section.dart';
import 'package:tool_lab/tools/todo/widgets/todo_schedule_section.dart';
import 'package:tool_lab/tools/todo/widgets/todo_steps_section.dart';
import 'package:tool_lab/tools/todo/widgets/todo_undo.dart';

/// Everything about one task. Used as the right pane and as a pushed page.
class TodoTaskDetail extends StatelessWidget {
  final String taskId;
  final VoidCallback? onClose;

  const TodoTaskDetail({super.key, required this.taskId, this.onClose});

  @override
  Widget build(BuildContext context) {
    final task = context.select<TodoState, TodoTask?>(
      (s) => s.taskById(taskId),
    );
    final l10n = AppLocalizations.of(context);
    if (task == null) {
      return Center(child: Text(l10n.todoTaskMissing));
    }
    final state = context.read<TodoState>();
    final theme = Theme.of(context);
    final color = Color(state.listById(task.listId)?.color ?? 0xFF4FC3F7);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              _Card(
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TodoCheckCircle(
                          checked: task.completed,
                          color: color,
                          size: 26,
                          onTap: () async {
                            final notifier = TodoUndoNotifier.of(context);
                            final undo = await state.toggleCompleted(task);
                            if (!task.completed) {
                              notifier.show(
                                l10n.todoCompletedSnack(task.title),
                                undo,
                              );
                            }
                          },
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TodoEditField(
                              value: task.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                decoration: task.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              maxLines: null,
                              onSubmit: (v) => state.setTitle(task, v),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            task.important ? Icons.star : Icons.star_border,
                            color: task.important ? TodoColors.star : null,
                          ),
                          onPressed: () => state.toggleImportant(task),
                        ),
                      ],
                    ),
                    TodoStepsSection(task: task, color: color),
                  ],
                ),
              ),
              _Card(child: TodoScheduleSection(task: task)),
              _Card(child: TodoMetaSection(task: task)),
              _Card(child: TodoAttachmentsSection(task: task)),
              _Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TodoEditField(
                    value: task.note,
                    hint: l10n.todoAddNote,
                    minLines: 3,
                    maxLines: null,
                    multiline: true,
                    onSubmit: (v) => state.setNote(task, v),
                  ),
                ),
              ),
            ],
          ),
        ),
        _Footer(task: task, onClose: onClose),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final TodoTask task;
  final VoidCallback? onClose;

  const _Footer({required this.task, this.onClose});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = DateFormat.yMMMEd(l10n.localeName);
    final label = task.completed
        ? l10n.todoCompletedOn(
            format.format(
              DateTime.fromMillisecondsSinceEpoch(task.completedAt!),
            ),
          )
        : l10n.todoCreatedOn(
            format.format(DateTime.fromMillisecondsSinceEpoch(task.createdAt)),
          );
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            if (onClose != null)
              IconButton(
                tooltip: l10n.commonClose,
                icon: const Icon(Icons.last_page),
                onPressed: onClose,
              ),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.commonDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final state = context.read<TodoState>();
                final notifier = TodoUndoNotifier.of(context);
                if (onClose != null) {
                  onClose!();
                } else {
                  Navigator.maybePop(context);
                }
                final undo = await state.deleteTask(task);
                notifier.show(l10n.todoDeletedSnack(task.title), undo);
              },
            ),
          ],
        ),
      ),
    );
  }
}
