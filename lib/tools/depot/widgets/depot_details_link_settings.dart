import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';

import '../depot_details_link.dart';
import '../depot_state.dart';

class DepotDetailsLinkSettings extends StatelessWidget {
  const DepotDetailsLinkSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionLabel(
          title: l10n.depotDetailsLinkTitle,
          description: l10n.depotDetailsLinkDescription(
            DepotDetailsLink.placeholders.join(', '),
          ),
        ),
        for (final kind in DepotDetailsLinkKind.values)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _TemplateField(kind: kind),
          ),
      ],
    );
  }
}

class _TemplateField extends StatefulWidget {
  final DepotDetailsLinkKind kind;

  const _TemplateField({required this.kind});

  @override
  State<_TemplateField> createState() => _TemplateFieldState();
}

class _TemplateFieldState extends State<_TemplateField> with DisposeCleanup {
  late final TextEditingController _controller;
  late final DepotState _state;

  DepotDetailsLinkKind get _kind => widget.kind;

  @override
  void initState() {
    super.initState();
    _state = context.read<DepotState>();
    _controller = TextEditingController(text: _state.detailsUrlTemplate(_kind));
    onDispose(_controller.dispose);
    // The stored template may arrive after the field was built.
    _state.addListener(_syncFromState);
    onDispose(() => _state.removeListener(_syncFromState));
  }

  void _syncFromState() {
    final template = _state.detailsUrlTemplate(_kind);
    if (_controller.text != template) _controller.text = template;
  }

  void _onChanged(String template) =>
      _state.setDetailsUrlTemplate(_kind, template);

  void _reset() {
    _controller.text = _kind.defaultTemplate;
    _onChanged(_kind.defaultTemplate);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.url,
      autocorrect: false,
      onChanged: _onChanged,
      decoration: InputDecoration(
        labelText: switch (_kind) {
          DepotDetailsLinkKind.etf => l10n.depotDetailsLinkEtf,
          DepotDetailsLinkKind.fund => l10n.depotDetailsLinkFund,
          DepotDetailsLinkKind.stock => l10n.depotDetailsLinkStock,
        },
        hintText: _kind.defaultTemplate,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.restart_alt),
          tooltip: l10n.commonReset,
          onPressed: _reset,
        ),
      ),
    );
  }
}
