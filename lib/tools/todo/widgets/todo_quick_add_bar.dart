import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/todo_colors.dart';
import 'package:tool_lab/tools/todo/todo_format.dart';
import 'package:tool_lab/tools/todo/todo_quick_parser.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';

/// Add-a-task field. Dates, times, `#tags`, `!` and repeats typed into the
/// text are recognised and previewed as chips before the task is created.
class TodoQuickAddBar extends StatefulWidget {
  final Color accent;
  final FocusNode? focusNode;

  const TodoQuickAddBar({super.key, required this.accent, this.focusNode});

  @override
  State<TodoQuickAddBar> createState() => _TodoQuickAddBarState();
}

class _TodoQuickAddBarState extends State<TodoQuickAddBar> {
  final TextEditingController _controller = TextEditingController();
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  TodoQuickDraft? _draft;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    final text = _controller.text;
    final draft = text.trim().isEmpty ? null : TodoQuickParser.parse(text);
    setState(() => _draft = draft);
  }

  Future<void> _submit() async {
    final draft = _draft;
    if (draft == null || draft.title.trim().isEmpty) return;
    _controller.clear();
    await context.read<TodoState>().addTask(draft);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final draft = _draft;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.add, color: widget.accent),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: l10n.todoAddTaskHint,
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                if (draft != null)
                  IconButton(
                    icon: Icon(Icons.arrow_upward, color: widget.accent),
                    tooltip: l10n.commonAdd,
                    onPressed: _submit,
                  ),
              ],
            ),
            if (draft != null && draft.hasExtras)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(44, 0, 8, 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (draft.due != null)
                        _PreviewChip(
                          icon: Icons.event_outlined,
                          label: draft.hasTime
                              ? TodoFormat.dayTime(draft.due!, l10n)
                              : TodoFormat.day(draft.due!, l10n),
                        ),
                      if (draft.recurrence != null)
                        _PreviewChip(
                          icon: Icons.repeat,
                          label: TodoFormat.recurrence(draft.recurrence!, l10n),
                        ),
                      if (draft.important)
                        _PreviewChip(
                          icon: Icons.star,
                          label: l10n.todoImportant,
                          color: TodoColors.star,
                        ),
                      for (final tag in draft.tags)
                        _PreviewChip(icon: Icons.tag, label: tag),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _PreviewChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = color ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}
