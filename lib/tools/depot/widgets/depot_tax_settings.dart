import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';

import '../depot_portfolio_state.dart';
import '../market_data/bundesbank_base_rate_api.dart';
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
  bool _fetching = false;
  bool _fetchFailed = false;
  bool _fetchedNone = false;
  BundesbankBaseRate? _fetched;

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

  Future<void> _fetch() async {
    setState(() {
      _fetching = true;
      _fetchFailed = false;
      _fetched = null;
    });
    BundesbankBaseRate? fetched;
    var failed = false;
    try {
      fetched = await BundesbankBaseRateApi.fetch(_year);
    } catch (e) {
      errorLog('[DepotTaxSettings] Base rate fetch failed: $e');
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _fetching = false;
      _fetchFailed = failed;
      _fetched = fetched;
      _fetchedNone = !failed && fetched == null;
    });
  }

  void _apply(double rate) {
    context.read<DepotPortfolioState>().setBaseRate(rate);
    _controller.text = _percent.format(rate * 100);
    setState(() => _fetched = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    final error = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.error,
    );
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
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _fetching ? null : _fetch,
                icon: _fetching
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download_outlined),
                label: Text(l10n.depotTaxBaseRateFetch),
              ),
              if (_fetched case final fetched?) ...[
                Text(
                  l10n.depotTaxBaseRateFetched(
                    DateFormat.yMd(
                      Localizations.localeOf(context).toString(),
                    ).format(fetched.date),
                    '${_percent.format(fetched.rate * 100)} %',
                  ),
                  style: hint,
                ),
                FilledButton.tonal(
                  onPressed: () => _apply(fetched.rate),
                  child: Text(l10n.depotTaxBaseRateApply),
                ),
              ] else if (_fetchFailed)
                Text(l10n.depotTaxBaseRateFetchFailed, style: error)
              else if (_fetchedNone)
                Text(l10n.depotTaxBaseRateNone('$_year'), style: hint),
            ],
          ),
        ),
      ],
    );
  }
}
