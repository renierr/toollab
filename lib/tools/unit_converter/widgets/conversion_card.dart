import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../unit_converter_state.dart';
import '../unit_format.dart';
import 'unit_dropdown.dart';

/// The primary conversion surface: value input, from/to unit pickers, a swap
/// action and the live result.
class ConversionCard extends StatefulWidget {
  final Color accent;

  const ConversionCard({super.key, required this.accent});

  @override
  State<ConversionCard> createState() => _ConversionCardState();
}

class _ConversionCardState extends State<ConversionCard> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _seenRevision = -1;

  @override
  void initState() {
    super.initState();
    final state = context.read<UnitConverterState>();
    _controller.text = state.input;
    _seenRevision = state.inputRevision;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _syncController(UnitConverterState state) {
    if (state.inputRevision != _seenRevision) {
      _seenRevision = state.inputRevision;
      _controller.value = TextEditingValue(
        text: state.input,
        selection: TextSelection.collapsed(offset: state.input.length),
      );
    }
  }

  void _copyResult(String text, AppLocalizations l10n) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.ucCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = context.watch<UnitConverterState>();
    _syncController(state);

    final result = state.result;
    final resultText = result == null ? '' : formatUnitValue(result);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // From: value + unit
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                labelText: l10n.ucFrom,
                hintText: l10n.ucValueHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => context.read<UnitConverterState>().setInput(v),
            ),
            const SizedBox(height: 12),
            UnitDropdown(
              label: l10n.ucFrom,
              units: state.category.units,
              value: state.fromUnit,
              onChanged: (u) => context.read<UnitConverterState>().setFrom(u),
            ),
            // Swap
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Divider(color: theme.dividerColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Material(
                      color: widget.accent.withValues(alpha: 0.16),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: l10n.ucSwap,
                        icon: Icon(Icons.swap_vert, color: widget.accent),
                        onPressed: () =>
                            context.read<UnitConverterState>().swap(),
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: theme.dividerColor)),
                ],
              ),
            ),
            // To: result + unit
            _ResultDisplay(
              text: resultText,
              symbol: state.toUnit.symbol,
              label: l10n.ucTo,
              accent: widget.accent,
              onCopy: resultText.isEmpty
                  ? null
                  : () => _copyResult(resultText, l10n),
              copyTooltip: l10n.ucCopyResult,
            ),
            const SizedBox(height: 12),
            UnitDropdown(
              label: l10n.ucTo,
              units: state.category.units,
              value: state.toUnit,
              onChanged: (u) => context.read<UnitConverterState>().setTo(u),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultDisplay extends StatelessWidget {
  final String text;
  final String symbol;
  final String label;
  final Color accent;
  final VoidCallback? onCopy;
  final String copyTooltip;

  const _ResultDisplay({
    required this.text,
    required this.symbol,
    required this.label,
    required this.accent,
    required this.onCopy,
    required this.copyTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  text.isEmpty ? '—' : '$text $symbol',
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: copyTooltip,
            icon: const Icon(Icons.copy_outlined),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
