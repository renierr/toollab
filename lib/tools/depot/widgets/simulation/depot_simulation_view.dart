import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../../depot_format.dart';
import '../../depot_portfolio_state.dart';
import '../../depot_simulation_state.dart';
import '../../simulation/depot_sim_inputs.dart';
import '../depot_connect_card.dart';
import '../depot_section_scroll_view.dart';
import 'depot_sim_chart_card.dart';
import 'depot_sim_dividend_card.dart';
import 'depot_sim_inputs_card.dart';
import 'depot_sim_kpis.dart';
import 'depot_sim_notice.dart';
import 'depot_sim_strategy_card.dart';

enum _Section { inputs, result, chart, strategies, dividends }

class DepotSimulationView extends StatefulWidget {
  const DepotSimulationView({super.key});

  @override
  State<DepotSimulationView> createState() => _DepotSimulationViewState();
}

class _DepotSimulationViewState extends State<DepotSimulationView> {
  @override
  void initState() {
    super.initState();
    context.read<DepotSimulationState>().ensureLoaded();
  }

  Future<void> _pullToRefresh() => context.read<DepotPortfolioState>().sync();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portfolio = context.watch<DepotPortfolioState>();
    final simulation = context.watch<DepotSimulationState>();

    if (!portfolio.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!portfolio.isConnected && !portfolio.hasData) {
      return const DepotConnectCard();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) simulation.syncDepot(portfolio);
    });

    final format = DepotFormat.of(context, portfolio.currency);
    final inputs = simulation.inputs;
    final result = simulation.result;
    final problem = simulation.problem;
    final months = simulation.historyMonths;

    return DepotSectionScrollView<_Section>(
      onRefresh: _pullToRefresh,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      spacing: 0,
      header: [
        SizedBox(
          height: 4,
          child: simulation.running ? const LinearProgressIndicator() : null,
        ),
      ],
      sections: [
        DepotSection(
          id: _Section.inputs,
          label: l10n.depotSimNavInputs,
          icon: Icons.tune,
          child: DepotSimInputsCard(
            inputs: inputs,
            depot: simulation.depot,
            format: format,
          ),
        ),
        DepotSection(
          id: _Section.result,
          label: l10n.depotSimNavResult,
          icon: Icons.verified_outlined,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (problem != null)
                  DepotSimNotice(
                    text: switch (problem) {
                      DepotSimProblem.indexFailed => l10n.depotSimIndexFailed,
                      DepotSimProblem.noHistory => l10n.depotSimNoHistory,
                    },
                    warning: true,
                  )
                else if (result == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  DepotSimKpis(
                    result: result,
                    inputs: inputs,
                    strategy: simulation.strategy,
                    format: format,
                  ),
                  if (inputs.source == DepotSimSource.depot &&
                      months != null &&
                      months < DepotSimulationState.shortHistoryMonths)
                    DepotSimNotice(
                      text: l10n.depotSimShortHistory(months ~/ 12),
                      warning: true,
                    ),
                  DepotSimNotice(
                    text: l10n.depotSimResultHint(
                      result.runs,
                      months == null
                          ? ''
                          : l10n.depotSimHistoryYears(months ~/ 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (result != null && problem == null) ...[
          DepotSection(
            id: _Section.chart,
            label: l10n.depotSimNavChart,
            icon: Icons.area_chart_outlined,
            child: DepotSimChartCard(
              result: result,
              strategy: simulation.strategy,
              format: format,
            ),
          ),
          DepotSection(
            id: _Section.strategies,
            label: l10n.depotSimNavStrategies,
            icon: Icons.compare_arrows,
            child: DepotSimStrategyCard(
              result: result,
              inputs: inputs,
              format: format,
            ),
          ),
          DepotSection(
            id: _Section.dividends,
            label: l10n.depotSimNavDividends,
            icon: Icons.payments_outlined,
            child: DepotSimDividendCard(
              result: result,
              inputs: inputs,
              format: format,
            ),
          ),
        ],
      ],
    );
  }
}
