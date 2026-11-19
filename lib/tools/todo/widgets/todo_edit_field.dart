import 'package:material_ui/material_ui.dart';

/// Borderless inline editor that commits on submit and on focus loss, and
/// follows outside changes (sync, widget taps) while not being edited.
class TodoEditField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onSubmit;
  final String? hint;
  final TextStyle? style;
  final int? minLines;
  final int? maxLines;
  final bool multiline;
  final bool autofocus;
  final VoidCallback? onEditingDone;

  const TodoEditField({
    super.key,
    required this.value,
    required this.onSubmit,
    this.hint,
    this.style,
    this.minLines,
    this.maxLines = 1,
    this.multiline = false,
    this.autofocus = false,
    this.onEditingDone,
  });

  @override
  State<TodoEditField> createState() => _TodoEditFieldState();
}

class _TodoEditFieldState extends State<TodoEditField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) return;
      _commit();
      widget.onEditingDone?.call();
    });
  }

  @override
  void didUpdateWidget(TodoEditField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    if (_controller.text != widget.value) widget.onSubmit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      style: widget.style,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      keyboardType: widget.multiline
          ? TextInputType.multiline
          : TextInputType.text,
      textInputAction: widget.multiline ? null : TextInputAction.done,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        hintText: widget.hint,
      ),
      onSubmitted: widget.multiline ? null : (_) => _commit(),
      onTapOutside: (_) => _focus.unfocus(),
    );
  }
}
