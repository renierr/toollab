import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';

import '../depot_portfolio_state.dart';
import '../models/depot_advance_lump.dart';

/// The running year's base rate for the advance lump sum estimate.
class DepotTaxSettings extends StatefulWidget {
  const DepotTaxSettings({super.key});

  @override
  State<DepotTaxSettings> createState() => _DepotTaxSettingsState();
}

class _DepotTaxSettingsState extends State<DepotTaxSettings>
    with DisposeCleanup {
  final TextEditingController _controller = TextEditingController();
  late NumberFormat _percent;
  final int _year = DateTime.now().year;
  bool _filled = false;

  @override
  void initState() {
    super.initState();
    onDispose(_controller.dispose);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _percent = NumberFormat('0.00', Localizations.localeOf(context).toString());
    if (_filled) return;
    _filled = true;
    final rate = context.read<DepotPortfolioState>().baseRate;
    _controller.text = rate == null ? '' : _percent.format(rate * 100);
  }

  void _onChanged(String text) {
    final trimmed = text.trim().replaceAll(',', '.');
    final state = context.read<DepotPortfolioState>();
    if (trimmed.isEmpty) {
      state.setBaseRate(null);
      return;
    }
    final percent = double.tryParse(trimmed);
    if (percent != null && percent >= 0) state.setBaseRate(percent / 100);
  }

  void _reset() {
    context.read<DepotPortfolioState>().setBaseRate(null);
    final rate = DepotAdvanceLump.baseRates[_year];
    _controller.text = rate == null ? '' : _percent.format(rate * 100);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final custom = context.select<DepotPortfolioState, bool>(
      (s) => s.hasCustomBaseRate,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionLabel(
          title: l10n.depotTaxSettingsTitle,
          description: l10n.depotTaxSettingsDescription,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: _onChanged,
            decoration: InputDecoration(
              labelText: l10n.depotTaxBaseRate('$_year'),
              suffixText: '%',
              border: const OutlineInputBorder(),
              suffixIcon: custom
                  ? IconButton(
                      icon: const Icon(Icons.restart_alt),
                      tooltip: l10n.commonReset,
                      onPressed: _reset,
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
