import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tool_lab/l10n/app_localizations.dart';

import '../sudoku_colors.dart';
import '../sudoku_state.dart';

class SudokuSettingsSheet {
  SudokuSettingsSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: SudokuColors.of(context).board,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _SettingsSheet(),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = SudokuColors.of(context);
    final s = context.watch<SudokuState>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sudokuSettingsTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.given,
            ),
          ),
          const SizedBox(height: 12),
          _SettingSwitch(
            title: l10n.sudokuHaptics,
            subtitle: l10n.sudokuHapticsSubtitle,
            value: s.hapticsEnabled,
            onChanged: s.setHapticsEnabled,
          ),
          _SettingSwitch(
            title: l10n.sudokuAutoCheck,
            value: s.autoCheck,
            onChanged: s.setAutoCheck,
          ),
          _SettingSwitch(
            title: l10n.sudokuHighlightConflicts,
            value: s.highlightConflicts,
            onChanged: s.setHighlightConflicts,
          ),
          _SettingSwitch(
            title: l10n.sudokuHighlightSameNumber,
            value: s.highlightSameNumber,
            onChanged: s.setHighlightSameNumber,
          ),
          _SettingSwitch(
            title: l10n.sudokuShowTimer,
            value: s.showTimer,
            onChanged: s.setShowTimer,
          ),
        ],
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingSwitch({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = SudokuColors.of(context);
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: TextStyle(color: colors.given)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: TextStyle(color: colors.note)),
    );
  }
}
