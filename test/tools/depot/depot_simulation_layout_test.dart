import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localization_delegates.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/depot/depot_format.dart';
import 'package:tool_lab/tools/depot/depot_simulation_state.dart';
import 'package:tool_lab/tools/depot/simulation/depot_sim_engine.dart';
import 'package:tool_lab/tools/depot/simulation/depot_sim_inputs.dart';
import 'package:tool_lab/tools/depot/widgets/simulation/depot_sim_chart_card.dart';
import 'package:tool_lab/tools/depot/widgets/simulation/depot_sim_dividend_card.dart';
import 'package:tool_lab/tools/depot/widgets/simulation/depot_sim_inputs_card.dart';
import 'package:tool_lab/tools/depot/widgets/simulation/depot_sim_kpis.dart';
import 'package:tool_lab/tools/depot/widgets/simulation/depot_sim_strategy_card.dart';

void main() {
  const depot = DepotSimDepotData(
    value: 1234567.89,
    invested: 876543.21,
    monthlySavings: 1500,
    dividendYield: 0.025,
    partialExemption: 0.3,
    taxAllowance: 1000,
    monthlyReturns: [],
  );
  const inputs = DepotSimInputs(source: DepotSimSource.manual);
  final result = DepotSimEngine.run(
    DepotSimParams.of(inputs, depot, runs: 200),
  );

  for (final width in [320.0, 1000.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('simulation cards fit $width at text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final state = DepotSimulationState(
          runner: (_) async => result,
          indexLoader: (_) async => const [],
        );
        addTearDown(state.dispose);
        final format = DepotFormat('de', 'EUR');

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: state,
            child: MaterialApp(
              locale: const Locale('de'),
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: ListView(
                  children: [
                    DepotSimInputsCard(
                      inputs: inputs,
                      depot: depot,
                      format: format,
                    ),
                    DepotSimKpis(
                      result: result,
                      inputs: inputs,
                      strategy: DepotSimStrategy.fixed,
                      format: format,
                    ),
                    DepotSimChartCard(
                      result: result,
                      strategy: DepotSimStrategy.guardrails,
                      format: format,
                    ),
                    DepotSimStrategyCard(
                      result: result,
                      inputs: inputs,
                      format: format,
                    ),
                    DepotSimDividendCard(
                      result: result,
                      inputs: inputs,
                      format: format,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.byType(CustomPaint).last, warnIfMissed: false);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
