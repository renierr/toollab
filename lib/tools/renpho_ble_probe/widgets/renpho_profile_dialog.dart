import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../renpho_measurement.dart';

/// Sex, height and birth date drive every calculated figure, so the tool asks
/// for them before the first scan rather than attributing a body composition
/// to invented defaults.
class RenphoProfileDialog extends StatefulWidget {
  final RenphoProfile profile;
  final bool firstRun;

  const RenphoProfileDialog({
    super.key,
    required this.profile,
    this.firstRun = false,
  });

  static Future<RenphoProfile?> show(
    BuildContext context, {
    required RenphoProfile profile,
    bool firstRun = false,
  }) => showDialog<RenphoProfile>(
    context: context,
    barrierDismissible: !firstRun,
    builder: (_) => RenphoProfileDialog(profile: profile, firstRun: firstRun),
  );

  @override
  State<RenphoProfileDialog> createState() => _RenphoProfileDialogState();
}

class _RenphoProfileDialogState extends State<RenphoProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.profile.name,
  );
  late final TextEditingController _height = TextEditingController(
    text: widget.profile.heightCm.toStringAsFixed(1),
  );
  late String _sex = widget.profile.sex;
  late DateTime _birthDate = widget.profile.birthDate;

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    return ResponsiveAlertDialog(
      scrollable: true,
      icon: const Icon(Icons.person_outline),
      title: Text(l10n.renphoProfileTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.firstRun) ...[
              Text(
                l10n.renphoProfileFirstRunHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.renphoProfileName,
                helperText: l10n.renphoProfileNameHelper,
              ),
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cake_outlined),
              title: Text(l10n.renphoProfileBirthDate),
              subtitle: Text(DateFormat.yMMMd(locale).format(_birthDate)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickBirthDate,
            ),
          ],
        ),
      ),
      actions: [
        if (!widget.firstRun)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
        FilledButton(onPressed: _save, child: Text(l10n.commonSave)),
      ],
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final height = double.parse(_height.text.replaceAll(',', '.'));
    Navigator.pop(
      context,
      widget.profile.copyWith(
        name: _name.text.trim().isEmpty ? 'User' : _name.text.trim(),
        sex: _sex,
        heightCm: height,
        birthDate: _birthDate,
        configured: true,
      ),
    );
  }
}
