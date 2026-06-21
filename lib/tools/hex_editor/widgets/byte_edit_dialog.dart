import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class ByteEditDialog extends StatefulWidget {
  final int offset;
  final int initialValue;

  const ByteEditDialog({
    super.key,
    required this.offset,
    required this.initialValue,
  });

  static Future<int?> show({
    required BuildContext context,
    required int offset,
    required int initialValue,
  }) {
    return showDialog<int>(
      context: context,
      builder: (context) =>
          ByteEditDialog(offset: offset, initialValue: initialValue),
    );
  }

  @override
  State<ByteEditDialog> createState() => _ByteEditDialogState();
}

class _ByteEditDialogState extends State<ByteEditDialog> {
  late final TextEditingController _hexController;
  late final TextEditingController _decController;
  late final TextEditingController _asciiController;

  int _value = 0;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;

    _hexController = TextEditingController(
      text: _value.toRadixString(16).padLeft(2, '0').toUpperCase(),
    );
    _decController = TextEditingController(text: _value.toString());
    _asciiController = TextEditingController(
      text: _isPrintable(_value) ? String.fromCharCode(_value) : '',
    );
  }

  bool _isPrintable(int byte) {
    return byte >= 32 && byte <= 126;
  }

  void _updateValue(
    int newValue, {
    bool hex = false,
    bool dec = false,
    bool ascii = false,
  }) {
    if (newValue < 0 || newValue > 255) return;
    _value = newValue;

    if (!hex) {
      _hexController.text = _value
          .toRadixString(16)
          .padLeft(2, '0')
          .toUpperCase();
    }
    if (!dec) {
      _decController.text = _value.toString();
    }
    if (!ascii) {
      _asciiController.text = _isPrintable(_value)
          ? String.fromCharCode(_value)
          : '';
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    _decController.dispose();
    _asciiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final offsetStr =
        '0x${widget.offset.toRadixString(16).padLeft(8, '0').toUpperCase()}';

    return AlertDialog(
      title: Text(
        l10n.hexEditorEditByteTitle(offsetStr),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _hexController,
              decoration: InputDecoration(
                labelText: '${l10n.hexEditorEditByteHex} (00 - FF)',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
              maxLength: 2,
              onChanged: (val) {
                final cleaned = val.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
                if (cleaned != val) {
                  _hexController.value = TextEditingValue(
                    text: cleaned,
                    selection: TextSelection.collapsed(offset: cleaned.length),
                  );
                }
                if (cleaned.isNotEmpty) {
                  final parsed = int.tryParse(cleaned, radix: 16);
                  if (parsed != null) {
                    _updateValue(parsed, hex: true);
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _decController,
              decoration: const InputDecoration(
                labelText: 'Decimal (0 - 255)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (val) {
                final cleaned = val.replaceAll(RegExp(r'[^0-9]'), '');
                if (cleaned != val) {
                  _decController.value = TextEditingValue(
                    text: cleaned,
                    selection: TextSelection.collapsed(offset: cleaned.length),
                  );
                }
                if (cleaned.isNotEmpty) {
                  final parsed = int.tryParse(cleaned);
                  if (parsed != null && parsed >= 0 && parsed <= 255) {
                    _updateValue(parsed, dec: true);
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _asciiController,
              decoration: InputDecoration(
                labelText: l10n.hexEditorEditByteAscii,
                border: const OutlineInputBorder(),
              ),
              maxLength: 1,
              onChanged: (val) {
                if (val.isNotEmpty) {
                  final charCode = val.codeUnitAt(0);
                  if (charCode <= 255) {
                    _updateValue(charCode, ascii: true);
                  }
                } else {
                  _updateValue(0, ascii: true);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_value),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
