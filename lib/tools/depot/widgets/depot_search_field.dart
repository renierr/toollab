import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';

/// Search box that keeps its own controller, so a rebuild from the filtered
/// list does not reset the cursor.
class DepotSearchField extends StatefulWidget {
  final String initialText;
  final String hint;
  final ValueChanged<String> onChanged;

  const DepotSearchField({
    super.key,
    required this.initialText,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<DepotSearchField> createState() => _DepotSearchFieldState();
}

class _DepotSearchFieldState extends State<DepotSearchField>
    with DisposeCleanup {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    onDispose(_controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        border: const OutlineInputBorder(),
        suffixIcon: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _controller.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}
