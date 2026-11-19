import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';
import 'package:tool_lab/tools/todo/widgets/todo_check_circle.dart';
import 'package:tool_lab/tools/todo/widgets/todo_edit_field.dart';

class TodoStepsSection extends StatefulWidget {
  final TodoTask task;
  final Color color;

  const TodoStepsSection({super.key, required this.task, required this.color});

  @override
  State<TodoStepsSection> createState() => _TodoStepsSectionState();
}

class _TodoStepsSectionState extends State<TodoStepsSection> {
  final TextEditingController _add = TextEditingController();
  final FocusNode _addFocus = FocusNode();

  @override
  void dispose() {
    _add.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _add.text.trim();
    if (text.isEmpty) return;
    _add.clear();
    await context.read<TodoState>().addStep(widget.task, text);
    _addFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<TodoState>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final task = widget.task;
    return Column(
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: task.steps.length,
          onReorderItem: (from, to) => state.reorderSteps(task, from, to),
          itemBuilder: (context, i) {
            final step = task.steps[i];
            return Row(
              key: ValueKey(step.id),
              children: [
                const SizedBox(width: 4),
                TodoCheckCircle(
                  checked: step.done,
                  color: widget.color,
                  size: 18,
                  onTap: () =>
                      state.updateStep(task, step.copyWith(done: !step.done)),
                ),
                Expanded(
                  child: TodoEditField(
                    value: step.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      decoration: step.done ? TextDecoration.lineThrough : null,
                      color: step.done
                          ? theme.colorScheme.onSurfaceVariant
                          : null,
                    ),
                    onSubmit: (v) => v.trim().isEmpty
                        ? state.removeStep(task, step)
                        : state.updateStep(
                            task,
                            step.copyWith(title: v.trim()),
                          ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: l10n.commonDelete,
                  onPressed: () => state.removeStep(task, step),
                ),
                ReorderableDragStartListener(
                  index: i,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.drag_indicator, size: 18),
                  ),
                ),
              ],
            );
          },
        ),
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Icon(Icons.add, size: 20, color: widget.color),
            ),
            Expanded(
              child: TextField(
                controller: _add,
                focusNode: _addFocus,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: task.steps.isEmpty
                      ? l10n.todoAddStep
                      : l10n.todoNextStep,
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
