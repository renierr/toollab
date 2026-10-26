import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../parsing/german_format.dart';

class DepotTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const DepotTextField({
    super.key,
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

/// Accepts either the German comma or a typed dot as the decimal separator.
class DepotNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const DepotNumberField({
    super.key,
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        validator: (value) => GermanFormat.parseUserNumber(value ?? '') == null
            ? l10n.depotImportInvalidNumber
            : null,
      ),
    );
  }
}

class DepotDateField extends StatelessWidget {
  final TextEditingController controller;

  const DepotDateField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(
        labelText: l10n.depotImportFieldDate,
        hintText: 'TT.MM.JJJJ',
      ),
      validator: (value) => GermanFormat.parseDate(value ?? '') == null
          ? l10n.depotImportInvalidDate
          : null,
    );
  }
}
