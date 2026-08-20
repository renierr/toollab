import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';

import '../renpho_ble_probe_state.dart';
import '../renpho_colors.dart';
import '../renpho_measurement.dart';
import 'renpho_measurement_details_page.dart';

class RenphoHistoryList extends StatelessWidget {
  final List<RenphoMeasurement> measurements;

  const RenphoHistoryList({super.key, required this.measurements});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (measurements.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          l10n.renphoHistoryEmpty,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: measurements.length,
      itemBuilder: (context, index) => RenphoHistoryListItem(
        measurement: measurements[index],
        previous: index + 1 < measurements.length
            ? measurements[index + 1]
            : null,
      ),
    );
  }
}

class RenphoHistoryListItem extends StatelessWidget {
  final RenphoMeasurement measurement;
  final RenphoMeasurement? previous;

  const RenphoHistoryListItem({
    super.key,
    required this.measurement,
    this.previous,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final delta = previous == null
        ? null
        : measurement.weightKg - previous!.weightKg;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: RenphoColors.weight.withValues(alpha: 0.15),
          child: Icon(
            measurement.stored
                ? Icons.history_toggle_off
                : Icons.monitor_weight_outlined,
            color: RenphoColors.weight,
          ),
        ),
        title: Text(
          '${measurement.weightKg.toStringAsFixed(2)} kg  ·  '
          '${measurement.bodyFatPercent.toStringAsFixed(1)} %',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${DateFormat.yMMMd(locale).add_Hm().format(measurement.measuredAt.toLocal())}'
          '  ·  ${l10n.renphoMetricMuscle} ${measurement.musclePercent.toStringAsFixed(1)} %',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: delta == null
            ? null
            : Text(
                '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)} kg',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: delta > 0
                      ? AppTheme.statusRed
                      : delta < 0
                      ? AppTheme.statusGreen
                      : theme.hintColor,
                ),
              ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                RenphoMeasurementDetailsPage(measurement: measurement),
          ),
        ),
        onLongPress: () => _delete(context),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<RenphoBleProbeState>();
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.renphoDeleteMeasurement,
      message: l10n.renphoDeleteMeasurementConfirm,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.commonDelete,
    );
    if (confirmed == true) await state.deleteMeasurement(measurement.uid);
  }
}
