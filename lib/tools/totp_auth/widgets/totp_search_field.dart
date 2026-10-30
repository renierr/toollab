import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class TotpSearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;

  const TotpSearchField({super.key, required this.onChanged});

  @override
  State<TotpSearchField> createState() => _TotpSearchFieldState();
}

class _TotpSearchFieldState extends State<TotpSearchField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _update(String value) {
    setState(() {});
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _controller,
        onChanged: _update,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l10n.totpSearchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: l10n.commonClear,
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    _update('');
                  },
                ),
          isDense: true,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
