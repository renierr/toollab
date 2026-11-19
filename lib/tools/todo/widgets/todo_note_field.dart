import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/widgets/todo_edit_field.dart';
import 'package:tool_lab/widgets/markdown_view.dart';

/// Note rendered as Markdown with tappable checkboxes; a tap elsewhere
/// switches to the editor.
class TodoNoteField extends StatefulWidget {
  final String note;
  final Color color;
  final ValueChanged<String> onSubmit;

  const TodoNoteField({
    super.key,
    required this.note,
    required this.color,
    required this.onSubmit,
  });

  @override
  State<TodoNoteField> createState() => _TodoNoteFieldState();
}

class _TodoNoteFieldState extends State<TodoNoteField> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_editing || widget.note.trim().isEmpty) {
      return TodoEditField(
        value: widget.note,
        hint: l10n.todoAddNote,
        minLines: 3,
        maxLines: null,
        multiline: true,
        autofocus: _editing,
        onSubmit: widget.onSubmit,
        onEditingDone: () {
          if (mounted && _editing) setState(() => _editing = false);
        },
      );
    }
    return Semantics(
      button: true,
      label: l10n.todoEditNote,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _editing = true),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: MarkdownView(
              data: widget.note,
              selectable: false,
              accentColor: widget.color,
              onCheckboxToggled: widget.onSubmit,
            ),
          ),
        ),
      ),
    );
  }
}
