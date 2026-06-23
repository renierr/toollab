import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../models/sketch_enums.dart';

const _palette = <String>[
  '#1E1E1E',
  '#495057',
  '#868E96',
  '#CED4DA',
  '#FFFFFF',
  '#E03131',
  '#F08C00',
  '#FFD43B',
  '#2F9E44',
  '#0CA678',
  '#1971C2',
  '#4263EB',
  '#7048E8',
  '#9C36B5',
  '#E64980',
  '#FFC9C9',
  '#FFEC99',
  '#B2F2BB',
  '#A5D8FF',
  '#EEBEFA',
];

/// Shows the color popup. Returns a hex string, the literal `transparent`
/// (when [allowNone] and "None" is chosen), or null on cancel.
Future<String?> showSketchColorPicker(
  BuildContext context, {
  required String? current,
  bool allowNone = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ColorPickerDialog(current: current, allowNone: allowNone),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  final String? current;
  final bool allowNone;

  const _ColorPickerDialog({required this.current, required this.allowNone});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _color;
  late bool _none;
  late final TextEditingController _hex;

  @override
  void initState() {
    super.initState();
    final parsed = colorFromHexOrNull(widget.current);
    _none = widget.allowNone && parsed == null;
    _color = parsed ?? const Color(0xFF1E1E1E);
    _hex = TextEditingController(
      text: hexFromColorWithAlpha(_color).replaceAll('#', ''),
    );
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _setColor(Color c, {bool syncHex = true}) {
    setState(() {
      _color = c;
      _none = false;
      if (syncHex) _hex.text = hexFromColorWithAlpha(c).replaceAll('#', '');
    });
  }

  void _applyHex(String value) {
    final clean = value.replaceAll('#', '').trim();
    if (clean.length == 3 || clean.length == 6 || clean.length == 8) {
      final c = colorFromHexOrNull(clean);
      if (c != null) _setColor(c, syncHex: false);
    }
  }

  int get _r => (_color.r * 255).round();
  int get _g => (_color.g * 255).round();
  int get _b => (_color.b * 255).round();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ResponsiveAlertDialog(
      title: Text(l10n.sketchColorTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.allowNone)
                  _PaletteSwatch(
                    color: null,
                    selected: _none,
                    onTap: () => setState(() => _none = true),
                  ),
                for (final hex in _palette)
                  _PaletteSwatch(
                    color: colorFromHexOrNull(hex)!,
                    selected:
                        !_none &&
                        hexFromColor(_color).toUpperCase() == hex.toUpperCase(),
                    onTap: () => _setColor(colorFromHexOrNull(hex)!),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _ChannelSlider(
              label: 'R',
              value: _r,
              color: Colors.red,
              onChanged: (v) => _setColor(_color.withValues(red: v / 255)),
            ),
            _ChannelSlider(
              label: 'G',
              value: _g,
              color: Colors.green,
              onChanged: (v) => _setColor(_color.withValues(green: v / 255)),
            ),
            _ChannelSlider(
              label: 'B',
              value: _b,
              color: Colors.blue,
              onChanged: (v) => _setColor(_color.withValues(blue: v / 255)),
            ),
            _ChannelSlider(
              label: l10n.sketchColorOpacity,
              value: (_color.a * 255).round(),
              color: theme.colorScheme.primary,
              onChanged: (v) => _setColor(_color.withValues(alpha: v / 255)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _none ? null : _color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: _none
                      ? Icon(
                          Icons.block,
                          color: theme.colorScheme.onSurfaceVariant,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hex,
                    decoration: const InputDecoration(
                      prefixText: '#',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
                      LengthLimitingTextInputFormatter(8),
                    ],
                    onChanged: (v) => _applyHex(v),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(_none ? 'transparent' : hexFromColorWithAlpha(_color)),
          child: Text(l10n.commonOk),
        ),
      ],
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color ?? Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: color == null
            ? Icon(
                Icons.block,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              )
            : null,
      ),
    );
  }
}

class _ChannelSlider extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final ValueChanged<double> onChanged;

  const _ChannelSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
        Expanded(
          child: Slider(
            min: 0,
            max: 255,
            value: value.toDouble(),
            activeColor: color,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.end)),
      ],
    );
  }
}
