import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../depot_labels.dart';
import '../models/depot_activity.dart';
import '../parsing/german_format.dart';
import 'depot_form_fields.dart';

class DepotActivityEditDialog extends StatefulWidget {
  final DepotActivity activity;

  const DepotActivityEditDialog({super.key, required this.activity});

  static Future<DepotActivity?> show(
    BuildContext context,
    DepotActivity activity,
  ) {
    return showDialog<DepotActivity>(
      context: context,
      builder: (_) => DepotActivityEditDialog(activity: activity),
    );
  }

  @override
  State<DepotActivityEditDialog> createState() =>
      _DepotActivityEditDialogState();
}

class _DepotActivityEditDialogState extends State<DepotActivityEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late DepotActivityType _type;
  late final TextEditingController _date;
  late final TextEditingController _isin;
  late final TextEditingController _name;
  late final TextEditingController _shares;
  late final TextEditingController _price;
  late final TextEditingController _amount;
  late final TextEditingController _tax;
  late final TextEditingController _fee;

  @override
  void initState() {
    super.initState();
    final a = widget.activity;
    _type = a.type;
    _date = TextEditingController(text: DepotLabels.date(a.date));
    _isin = TextEditingController(text: a.isin);
    _name = TextEditingController(text: a.securityName);
    _shares = TextEditingController(text: DepotLabels.number(a.shares, 9));
    _price = TextEditingController(text: DepotLabels.number(a.price, 6));
    _amount = TextEditingController(text: DepotLabels.number(a.amount, 2));
    _tax = TextEditingController(text: DepotLabels.number(a.tax, 2));
    _fee = TextEditingController(text: DepotLabels.number(a.fee, 2));
  }

  @override
  void dispose() {
    for (final controller in [
      _date,
      _isin,
      _name,
      _shares,
      _price,
      _amount,
      _tax,
      _fee,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    double number(TextEditingController c) =>
        GermanFormat.parseUserNumber(c.text) ?? 0;

    Navigator.of(context).pop(
      widget.activity.copyWith(
        type: _type,
        date: GermanFormat.parseDate(_date.text),
        isin: _isin.text.trim().toUpperCase(),
        securityName: _name.text.trim(),
        shares: number(_shares),
        price: number(_price),
        amount: number(_amount),
        tax: number(_tax),
        fee: number(_fee),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ResponsiveAlertDialog(
      scrollable: true,
      title: Text(l10n.depotImportEditTitle),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<DepotActivityType>(
                initialValue: _type,
                decoration: InputDecoration(
                  labelText: l10n.depotImportFieldType,
                ),
                items: DepotActivityType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(DepotLabels.type(l10n, type)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: 8),
              DepotDateField(controller: _date),
              DepotTextField(
                controller: _isin,
                label: l10n.depotImportFieldIsin,
              ),
              DepotTextField(
                controller: _name,
                label: l10n.depotImportFieldName,
              ),
              DepotNumberField(
                controller: _shares,
                label: l10n.depotImportFieldShares,
              ),
              DepotNumberField(
                controller: _price,
                label: l10n.depotImportFieldPrice,
              ),
              DepotNumberField(
                controller: _amount,
                label: l10n.depotImportFieldAmount,
              ),
              DepotNumberField(
                controller: _tax,
                label: l10n.depotImportFieldTax,
              ),
              DepotNumberField(
                controller: _fee,
                label: l10n.depotImportFieldFee,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.commonSave)),
      ],
    );
  }
}
