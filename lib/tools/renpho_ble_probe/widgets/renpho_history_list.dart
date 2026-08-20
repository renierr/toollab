import 'dart:async';

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

/// The history, one collapsible block per month. The newest month opens; the
/// rest stay shut and their measurements are never read until they are opened,
/// so years of scans cost a month index rather than a list of every row.
class RenphoHistoryList extends StatelessWidget {
  const RenphoHistoryList({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RenphoBleProbeState>();
    final l10n = AppLocalizations.of(context);
    final months = state.historyMonths;
    if (months.isEmpty) {
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
    return Column(
      children: [
        for (var index = 0; index < months.length; index++)
          _MonthSection(
            key: ValueKey(months[index].key),
            month: months[index],
            initiallyExpanded: index == 0,
          ),
      ],
    );
  }
}

class _MonthSection extends StatefulWidget {
  final RenphoHistoryMonth month;
  final bool initiallyExpanded;

  const _MonthSection({
    super.key,
    required this.month,
    required this.initiallyExpanded,
  });

  @override
  State<_MonthSection> createState() => _MonthSectionState();
}

class _MonthSectionState extends State<_MonthSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  void initState() {
    super.initState();
    if (_expanded) _ensureLoaded();
  }

  void _ensureLoaded() {
    final state = context.read<RenphoBleProbeState>();
    if (state.monthRows(widget.month) == null) {
      unawaited(state.loadMonth(widget.month));
    }
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) _ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RenphoBleProbeState>();
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final rows = state.monthRows(widget.month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat.yMMMM(locale).format(widget.month.start),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${widget.month.count}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _expanded ? 0.0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more, size: 22),
                ),
              ],
            ),
          ),
        ),
        // Built only while open. An AnimatedCrossFade would build the rows of
        // every collapsed month as well, which is the cost this avoids.
        if (_expanded)
          if (rows == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            for (var index = 0; index < rows.length; index++)
              RenphoHistoryListItem(
                measurement: rows[index],
                previous: index + 1 < rows.length ? rows[index + 1] : null,
              ),
      ],
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
            measurement.imported
                ? Icons.file_upload_outlined
                : measurement.stored
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
