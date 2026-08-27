import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/health_connect_actions.dart';
import 'package:tool_lab/widgets/info_card.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';

import '../debug/health_debug_data.dart';
import '../debug/health_debug_seeder.dart';
import '../health_debug_origin.dart';
import '../health_dashboard_state.dart';

/// Debug-only screen that fills Health Connect with a generated history so the
/// dashboard has something to render, and removes it again.
class HealthDebugSeedPage extends StatefulWidget {
  const HealthDebugSeedPage({super.key});

  @override
  State<HealthDebugSeedPage> createState() => _HealthDebugSeedPageState();
}

class _HealthDebugSeedPageState extends State<HealthDebugSeedPage>
    with DisposeCleanup<HealthDebugSeedPage> {
  static const _ranges = [7, 30, 90, 180, 365];

  int _days = 90;
  Set<HealthDebugGroup> _groups = HealthDebugPreset.everything.groups;
  bool _busy = false;
  String? _status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthDebugSeedTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: InfoCard(
              icon: Icons.bug_report_outlined,
              title: l10n.healthDebugSeedTitle,
              titleColor: AppTheme.statusAmber,
              child: Text(l10n.healthDebugSeedWarning),
            ),
          ),
          SettingsSectionLabel(title: l10n.healthDebugSeedRange),
          _ChipRow(
            children: [
              for (final days in _ranges)
                ChoiceChip(
                  label: Text(l10n.healthDebugSeedDays(days)),
                  selected: _days == days,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _days = days),
                ),
            ],
          ),
          SettingsSectionLabel(
            title: l10n.healthDebugSeedPresets,
            description: l10n.healthDebugSeedPresetsHint,
          ),
          _ChipRow(
            children: [
              for (final preset in HealthDebugPreset.values)
                ChoiceChip(
                  label: Text(_presetLabel(l10n, preset)),
                  selected: _setEquals(_groups, preset.groups),
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _groups = preset.groups),
                ),
            ],
          ),
          SettingsSectionLabel(title: l10n.healthDebugSeedGroups),
          for (final group in HealthDebugGroup.values)
            CheckboxListTile.adaptive(
              dense: true,
              title: Text(_groupLabel(l10n, group)),
              value: _groups.contains(group),
              onChanged: _busy ? null : (value) => _toggle(group, value),
            ),
          SettingsSectionLabel(title: l10n.healthDebugSeedActions),
          ListTile(
            leading: const Icon(Icons.auto_fix_high_outlined),
            title: Text(l10n.healthDebugSeedGenerate),
            subtitle: Text(_status ?? l10n.healthDebugSeedGenerateSubtitle),
            trailing: _busy ? const BusyTileSpinner() : null,
            onTap: _busy ? null : _seed,
          ),
          ListTile(
            leading: const Icon(
              Icons.delete_sweep_outlined,
              color: AppTheme.statusRed,
            ),
            title: Text(l10n.healthDebugSeedClear),
            subtitle: Text(l10n.healthDebugSeedClearSubtitle),
            onTap: _busy ? null : _clear,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Text(
              l10n.healthDebugSeedImportHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggle(HealthDebugGroup group, bool? value) {
    setState(() {
      final next = {..._groups};
      if (value == true) {
        next.add(group);
      } else {
        next.remove(group);
      }
      _groups = next;
    });
  }

  Future<void> _seed() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_groups.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.healthDebugSeedNoGroups)),
      );
      return;
    }
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.healthDebugSeedGenerate,
      message: l10n.healthDebugSeedGenerateConfirm(_days, _groups.length),
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.healthDebugSeedGenerateAction,
      confirmColor: AppTheme.statusAmber,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await const HealthDebugSeeder().seed(
        days: _days,
        groups: _groups,
        onProgress: (_, written) {
          if (mounted) {
            setState(() => _status = l10n.healthDebugSeedProgress(written));
          }
        },
      );
      messenger.showSnackBar(
        SnackBar(content: Text(_message(l10n, result, seeding: true))),
      );
    } finally {
      if (mounted) _finish();
    }
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<HealthDashboardState>();
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.healthDebugSeedClear,
      message: l10n.healthDebugSeedClearConfirm,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.healthDebugSeedClearAction,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await const HealthDebugSeeder().clear(
        onProgress: (_, removed) {
          if (mounted) {
            setState(() => _status = l10n.healthDebugSeedProgress(removed));
          }
        },
      );
      // Deleting in Health Connect leaves the rows already imported behind, and
      // the change sync only catches deletions for the shapes that carry a
      // record id - so the generated source's rows go too. Nothing real is ever
      // filed under that package, so this cannot reach anything else.
      if (result.outcome == HealthDebugOutcome.ran) {
        await state.deleteAppData(healthDebugPackage);
      }
      messenger.showSnackBar(
        SnackBar(content: Text(_message(l10n, result, seeding: false))),
      );
    } finally {
      if (mounted) _finish();
    }
  }

  void _finish() => setState(() {
    _busy = false;
    _status = null;
  });

  String _message(
    AppLocalizations l10n,
    HealthDebugResult result, {
    required bool seeding,
  }) => switch (result.outcome) {
    HealthDebugOutcome.unsupported => l10n.healthDebugSeedUnsupported,
    HealthDebugOutcome.noPermission => l10n.healthDebugSeedNoPermission,
    HealthDebugOutcome.nothingSelected => l10n.healthDebugSeedNoGroups,
    HealthDebugOutcome.failed => l10n.healthDebugSeedFailed,
    HealthDebugOutcome.ran when result.failed > 0 =>
      l10n.healthDebugSeedPartial(result.records, result.failed),
    HealthDebugOutcome.ran when seeding => l10n.healthDebugSeedDone(
      result.records,
    ),
    HealthDebugOutcome.ran => l10n.healthDebugSeedClearDone(result.records),
  };

  static String _presetLabel(AppLocalizations l10n, HealthDebugPreset preset) =>
      switch (preset) {
        HealthDebugPreset.everyday => l10n.healthDebugPresetEveryday,
        HealthDebugPreset.athlete => l10n.healthDebugPresetAthlete,
        HealthDebugPreset.clinical => l10n.healthDebugPresetClinical,
        HealthDebugPreset.everything => l10n.healthDebugPresetEverything,
      };

  static String _groupLabel(AppLocalizations l10n, HealthDebugGroup group) =>
      switch (group) {
        HealthDebugGroup.activity => l10n.healthDebugGroupActivity,
        HealthDebugGroup.heart => l10n.healthDebugGroupHeart,
        HealthDebugGroup.sleep => l10n.healthDebugGroupSleep,
        HealthDebugGroup.workouts => l10n.healthDebugGroupWorkouts,
        HealthDebugGroup.body => l10n.healthDebugGroupBody,
        HealthDebugGroup.vitals => l10n.healthDebugGroupVitals,
        HealthDebugGroup.hydration => l10n.healthDebugGroupHydration,
      };

  static bool _setEquals(Set<HealthDebugGroup> a, Set<HealthDebugGroup> b) =>
      a.length == b.length && a.containsAll(b);
}

class _ChipRow extends StatelessWidget {
  final List<Widget> children;

  const _ChipRow({required this.children});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Wrap(spacing: 8, runSpacing: 8, children: children),
  );
}
