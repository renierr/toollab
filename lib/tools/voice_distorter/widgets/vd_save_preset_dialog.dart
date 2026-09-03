import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/responsive_alert_dialog.dart';
import '../voice_distorter_state.dart';

Future<void> showSavePresetDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final state = context.read<VoiceDistorterState>();
  final controller = TextEditingController();

  final String? name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => ResponsiveAlertDialog(
      title: Text(l10n.voiceDistorterSavePresetTitle),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.voiceDistorterPresetNameLabel,
        ),
        onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: Text(l10n.commonSave),
        ),
      ],
    ),
  );

  controller.dispose();
  if (name != null && name.isNotEmpty) {
    await state.saveCustomPreset(name);
  }
}
