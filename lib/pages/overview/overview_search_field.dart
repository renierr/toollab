import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/keyboard_on_activate.dart';

class OverviewSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// On a TV focus alone must not open the keyboard, or the remote's Down
  /// lands in it; OK opens it instead.
  final bool keyboardOnActivate;

  const OverviewSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.keyboardOnActivate = false,
  });

  void _clear() {
    controller.clear();
    onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return KeyboardOnActivate(
      enabled: keyboardOnActivate,
      builder: (context, gate) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => TextField(
          controller: controller,
          focusNode: gate.focusNode,
          readOnly: gate.readOnly,
          onTap: gate.onTap,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: l10n.coreOverviewSearchHint,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: _clear,
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
