import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../../depot_format.dart';
import '../../depot_simulation_state.dart';
import '../../simulation/depot_sim_inputs.dart';
import '../depot_mode_chips.dart';
import 'depot_sim_number_field.dart';

class DepotSimInputsCard extends StatelessWidget {
  final DepotSimInputs inputs;
  final DepotSimDepotData? depot;
  final DepotFormat format;

  const DepotSimInputsCard({
    super.key,
    required this.inputs,
    required this.depot,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.read<DepotSimulationState>();
    final depot = this.depot;
    void set(DepotSimInputs next) => state.setInputs(next);
    String percent(double fraction) =>
        format.percent(fraction * 100, signed: false);

    return Card(
      child: ExpansionTile(
        key: const PageStorageKey('depot-sim-inputs'),
        initiallyExpanded: true,
        title: Text(
          l10n.depotSimInputsTitle,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          l10n.depotSimInputsHint,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final cramped = constraints.maxWidth < 420;
              final width = cramped ? (constraints.maxWidth - 12) / 2 : 176.0;
              final years = l10n.depotSimUnitYears;
              final perMonth = l10n.depotSimUnitPerMonth(format.currencySymbol);

              DepotSimNumberField field(
                String label,
                double? value,
                ValueChanged<double?> onChanged, {
                String? hint,
                String? suffix,
                bool percent = false,
                bool integer = false,
                bool optional = false,
              }) => DepotSimNumberField(
                label: label,
                value: value,
                onChanged: onChanged,
                width: width,
                hint: hint,
                suffix: suffix,
                percent: percent,
                integer: integer,
                optional: optional,
              );

              return Column(
                // The tile keeps its expanded flag under its own key; the
                // fields' scroll offsets must not read it back.
                key: const PageStorageKey('depot-sim-fields'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Group(
                    label: l10n.depotSimGroupPerson,
                    children: [
                      field(
                        l10n.depotSimAge,
                        inputs.age.toDouble(),
                        (v) => set(inputs.copyWith(age: v!.round())),
                        suffix: years,
                        integer: true,
                      ),
                      field(
                        l10n.depotSimRetireAge,
                        inputs.retireAge.toDouble(),
                        (v) => set(inputs.copyWith(retireAge: v!.round())),
                        suffix: years,
                        integer: true,
                      ),
                      field(
                        l10n.depotSimPensionAge,
                        inputs.pensionAge.toDouble(),
                        (v) => set(inputs.copyWith(pensionAge: v!.round())),
                        suffix: years,
                        integer: true,
                      ),
                      field(
                        l10n.depotSimEndAge,
                        inputs.endAge.toDouble(),
                        (v) => set(inputs.copyWith(endAge: v!.round())),
                        suffix: years,
                        integer: true,
                      ),
                    ],
                  ),
                  _Group(
                    label: l10n.depotSimGroupMoney,
                    children: [
                      field(
                        l10n.depotSimExpenses,
                        inputs.expenses,
                        (v) => set(inputs.copyWith(expenses: v)),
                        suffix: perMonth,
                      ),
                      field(
                        l10n.depotSimPension,
                        inputs.pension,
                        (v) => set(inputs.copyWith(pension: v)),
                        suffix: perMonth,
                      ),
                      field(
                        l10n.depotSimSavings,
                        inputs.savings,
                        (v) => set(inputs.copyWith(savings: () => v)),
                        hint: depot == null
                            ? null
                            : format.money(depot.monthlySavings),
                        suffix: perMonth,
                        optional: true,
                      ),
                      field(
                        l10n.depotSimStartValue,
                        inputs.startValue,
                        (v) => set(inputs.copyWith(startValue: () => v)),
                        hint: depot == null ? null : format.money(depot.value),
                        suffix: format.currencySymbol,
                        optional: true,
                      ),
                    ],
                  ),
                  _Group(
                    label: l10n.depotSimGroupMarket,
                    children: [
                      field(
                        l10n.depotSimInflation,
                        inputs.inflation,
                        (v) => set(inputs.copyWith(inflation: v)),
                        suffix: '%',
                        percent: true,
                      ),
                      field(
                        l10n.depotSimDividendYield,
                        inputs.dividendYield,
                        (v) => set(inputs.copyWith(dividendYield: () => v)),
                        hint: depot == null
                            ? null
                            : percent(depot.dividendYield),
                        suffix: '%',
                        percent: true,
                        optional: true,
                      ),
                      field(
                        l10n.depotSimReturnAdjustment,
                        inputs.returnAdjustment,
                        (v) => set(inputs.copyWith(returnAdjustment: v)),
                        suffix: '%',
                        percent: true,
                      ),
                      if (inputs.source == DepotSimSource.manual) ...[
                        field(
                          l10n.depotSimManualReturn,
                          inputs.manualReturn,
                          (v) => set(inputs.copyWith(manualReturn: v)),
                          suffix: '%',
                          percent: true,
                        ),
                        field(
                          l10n.depotSimManualVolatility,
                          inputs.manualVolatility,
                          (v) => set(inputs.copyWith(manualVolatility: v)),
                          suffix: '%',
                          percent: true,
                        ),
                      ],
                    ],
                  ),
                  _Group(
                    label: l10n.depotSimGroupTax,
                    children: [
                      field(
                        l10n.depotSimTaxRate,
                        inputs.taxRate,
                        (v) => set(inputs.copyWith(taxRate: v)),
                        suffix: '%',
                        percent: true,
                      ),
                      field(
                        l10n.depotSimPartialExemption,
                        inputs.partialExemption,
                        (v) => set(inputs.copyWith(partialExemption: () => v)),
                        hint: depot == null
                            ? null
                            : percent(depot.partialExemption),
                        suffix: '%',
                        percent: true,
                        optional: true,
                      ),
                      field(
                        l10n.depotSimTargetSuccess,
                        inputs.targetSuccess,
                        (v) => set(inputs.copyWith(targetSuccess: v)),
                        suffix: '%',
                        percent: true,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(l10n.depotSimSource, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          DepotModeChips<DepotSimSource>(
            selected: inputs.source,
            options: [
              (DepotSimSource.world, l10n.depotSimSourceWorld),
              (DepotSimSource.sp500, l10n.depotSimSourceSp500),
              (DepotSimSource.depot, l10n.depotSimSourceDepot),
              (DepotSimSource.manual, l10n.depotSimSourceManual),
            ],
            onSelected: (source) => set(inputs.copyWith(source: source)),
          ),
          const SizedBox(height: 4),
          Text(
            switch (inputs.source) {
              DepotSimSource.world ||
              DepotSimSource.sp500 => l10n.depotSimSourceIndexHint,
              DepotSimSource.depot => l10n.depotSimSourceDepotHint,
              DepotSimSource.manual => l10n.depotSimSourceManualHint,
            },
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _Group({required this.label, required this.children});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 12, children: children),
      ],
    ),
  );
}
