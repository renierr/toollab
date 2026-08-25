import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../renpho_ble_probe_state.dart';
import '../renpho_measurement.dart';

/// Asks for the three values every calculated figure needs before a guest
/// scan. Only an age in years is collected — a guest's birth date is more than
/// the tool needs for a reading it never keeps.
class RenphoGuestDialog extends StatefulWidget {
  final RenphoProfile profile;

  const RenphoGuestDialog({super.key, required this.profile});

  static Future<RenphoProfile?> show(
    BuildContext context, {
    required RenphoProfile profile,
  }) => showDialog<RenphoProfile>(
    context: context,
    builder: (_) => RenphoGuestDialog(profile: profile),
  );

  @override
  State<RenphoGuestDialog> createState() => _RenphoGuestDialogState();
}

class _RenphoGuestDialogState extends State<RenphoGuestDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _height = TextEditingController(
    text: widget.profile.heightCm.toStringAsFixed(1),
  );
  late String _sex = widget.profile.sex;
  late int _age = widget.profile.ageAt(DateTime.now()).clamp(1, 120);

  @override
  void dispose() {
    _height.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      scrollable: true,
      icon: const Icon(Icons.person_add_alt_outlined),
      title: Text(l10n.renphoGuestTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.renphoGuestHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _sex,
              decoration: InputDecoration(labelText: l10n.renphoProfileSex),
              items: [
                DropdownMenuItem(
                  value: 'male',
                  child: Text(l10n.renphoSexMale),
                ),
                DropdownMenuItem(
                  value: 'female',
                  child: Text(l10n.renphoSexFemale),
                ),
              ],
              onChanged: (value) => setState(() => _sex = value ?? _sex),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _height,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: l10n.renphoProfileHeight),
              validator: (value) {
                final parsed = double.tryParse(
                  (value ?? '').replaceAll(',', '.'),
                );
                if (parsed == null || parsed < 80 || parsed > 250) {
                  return l10n.renphoProfileHeightInvalid;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _age,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.renphoGuestAge),
              items: [
                for (var years = 1; years <= 120; years++)
                  DropdownMenuItem(value: years, child: Text('$years')),
              ],
              onChanged: (value) => setState(() => _age = value ?? _age),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.bluetooth_searching),
          label: Text(l10n.renphoGuestStart),
        ),
      ],
    );
  }

  void _start() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final now = DateTime.now();
    Navigator.pop(
      context,
      RenphoProfile(
        name: RenphoBleProbeState.guestUserName,
        sex: _sex,
        heightCm: double.parse(_height.text.replaceAll(',', '.')),
        // A birth date the requested age resolves back to; only the age is
        // ever used.
        birthDate: DateTime(now.year - _age, now.month, now.day),
        configured: true,
      ),
    );
  }
}
