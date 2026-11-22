import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/core/tool_page_state.dart';

import '../../parsing/german_format.dart';

/// A number input that reports on every valid edit; percent fields show and
/// take whole percents for a fraction. An empty optional field reports null.
class DepotSimNumberField extends StatefulWidget {
  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;
  final String? hint;
  final String? suffix;
  final bool percent;
  final bool integer;
  final bool optional;
  final double width;

  const DepotSimNumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.width,
    this.hint,
    this.suffix,
    this.percent = false,
    this.integer = false,
    this.optional = false,
  });

  @override
  State<DepotSimNumberField> createState() => _DepotSimNumberFieldState();
}

class _DepotSimNumberFieldState extends State<DepotSimNumberField>
    with DisposeCleanup {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    onDispose(_controller.dispose);
    onDispose(_focus.dispose);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.text.isEmpty) _controller.text = _format(widget.value);
  }

  @override
  void didUpdateWidget(covariant DepotSimNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && _parse(_controller.text) != widget.value) {
      _controller.text = _format(widget.value);
    }
  }

  String _format(double? value) {
    if (value == null) return '';
    final shown = widget.percent ? value * 100 : value;
    // No grouping: a lone dot would read back as a decimal point.
    return NumberFormat(
      widget.integer ? '0' : '0.##',
      Localizations.localeOf(context).toString(),
    ).format(shown);
  }

  double? _parse(String text) {
    final parsed = GermanFormat.parseUserNumber(text);
    if (parsed == null) return null;
    final value = widget.integer ? parsed.roundToDouble() : parsed;
    return widget.percent ? value / 100 : value;
  }

  void _onChanged(String text) {
    if (text.trim().isEmpty) {
      setState(() => _invalid = !widget.optional);
      if (widget.optional) widget.onChanged(null);
      return;
    }
    final value = _parse(text);
    setState(() => _invalid = value == null);
    if (value != null) widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    child: TextField(
      controller: _controller,
      focusNode: _focus,
      keyboardType: TextInputType.numberWithOptions(
        decimal: !widget.integer,
        signed: true,
      ),
      onChanged: _onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        floatingLabelBehavior: widget.hint != null
            ? FloatingLabelBehavior.always
            : null,
        suffixText: widget.suffix,
        isDense: true,
        border: const OutlineInputBorder(),
        errorText: _invalid ? '' : null,
        errorStyle: const TextStyle(height: 0, fontSize: 0),
      ),
    ),
  );
}
