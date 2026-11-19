import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_list_name.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';

/// List membership and tags.
class TodoMetaSection extends StatelessWidget {
  final TodoTask task;

  const TodoMetaSection({super.key, required this.task});

  Future<void> _pickList(BuildContext context) async {
    final state = context.read<TodoState>();
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final list in state.lists)
                ListTile(
                  leading: list.emoji.isNotEmpty
                      ? Text(list.emoji, style: const TextStyle(fontSize: 20))
                      : Icon(Icons.list_rounded, color: Color(list.color)),
                  title: Text(todoListName(list, l10n)),
                  trailing: list.shortId == task.listId
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(context, list.shortId),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && picked != task.listId) {
      await state.moveToList(task, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<TodoState>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final list = state.listById(task.listId);
    return Column(
      children: [
        ListTile(
          leading: list != null && list.emoji.isNotEmpty
              ? Text(list.emoji, style: const TextStyle(fontSize: 20))
              : Icon(
                  Icons.list_rounded,
                  color: list == null ? null : Color(list.color),
                ),
          title: Text(list == null ? '' : todoListName(list, l10n)),
          subtitle: Text(l10n.todoList),
          trailing: const Icon(Icons.swap_horiz),
          onTap: () => _pickList(context),
        ),
        const Divider(height: 1, indent: 56),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 16),
                child: Icon(
                  Icons.sell_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: _TagEditor(
                  tags: task.tags,
                  suggestions: state.allTags,
                  onChanged: (tags) => state.setTags(task, tags),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TagEditor extends StatefulWidget {
  final List<String> tags;
  final List<String> suggestions;
  final ValueChanged<List<String>> onChanged;

  const _TagEditor({
    required this.tags,
    required this.suggestions,
    required this.onChanged,
  });

  @override
  State<_TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<_TagEditor> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final tag = raw.trim().replaceAll('#', '').replaceAll(' ', '-');
    _controller.clear();
    if (tag.isEmpty ||
        widget.tags.any((t) => t.toLowerCase() == tag.toLowerCase())) {
      return;
    }
    widget.onChanged([...widget.tags, tag]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lower = widget.tags.map((t) => t.toLowerCase()).toSet();
    final query = _controller.text.trim().toLowerCase();
    final suggestions = widget.suggestions
        .where((s) => !lower.contains(s.toLowerCase()))
        .where((s) => query.isEmpty || s.toLowerCase().contains(query))
        .take(8)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final tag in widget.tags)
              InputChip(
                label: Text('#$tag'),
                onDeleted: () => widget.onChanged(
                  widget.tags.where((t) => t != tag).toList(),
                ),
              ),
          ],
        ),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: l10n.todoAddTag,
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: _add,
        ),
        if (suggestions.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in suggestions)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: Text('#$s'),
                  onPressed: () => _add(s),
                ),
            ],
          ),
      ],
    );
  }
}
