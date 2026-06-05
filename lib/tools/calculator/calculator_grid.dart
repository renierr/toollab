import 'package:flutter/material.dart';

enum _ButtonVariant { number, operator, clear, neutral, equals }

class CalculatorGrid extends StatelessWidget {
  static const _rows = [
    ['AC', '()', '%', '÷'],
    ['7', '8', '9', '×'],
    ['4', '5', '6', '−'],
    ['1', '2', '3', '+'],
    ['±', '0', '.', '='],
  ];

  final void Function(String) onInput;
  final VoidCallback onClear;
  final VoidCallback onBracket;
  final VoidCallback onNegate;
  final VoidCallback onEquals;

  const CalculatorGrid({
    super.key,
    required this.onInput,
    required this.onClear,
    required this.onBracket,
    required this.onNegate,
    required this.onEquals,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(_rows.length, (i) {
        final row = _rows[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: i < _rows.length - 1 ? 6 : 0),
            child: Row(
              children: row.map((label) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _buildButton(label),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildButton(String label) {
    return switch (label) {
      'AC' => _CalcButton(
        label: label,
        variant: _ButtonVariant.clear,
        onTap: onClear,
      ),
      '()' => _CalcButton(
        label: label,
        variant: _ButtonVariant.neutral,
        onTap: onBracket,
      ),
      '%' => _CalcButton(
        label: label,
        variant: _ButtonVariant.neutral,
        onTap: () => onInput('%'),
      ),
      '÷' || '×' || '−' || '+' => _CalcButton(
        label: label,
        variant: _ButtonVariant.operator,
        onTap: () => onInput(_operatorMap(label)),
      ),
      '=' => _CalcButton(
        label: label,
        variant: _ButtonVariant.equals,
        onTap: onEquals,
      ),
      '±' => _CalcButton(
        label: label,
        variant: _ButtonVariant.neutral,
        onTap: onNegate,
      ),
      _ => _CalcButton(
        label: label,
        variant: _ButtonVariant.number,
        onTap: () => onInput(label),
      ),
    };
  }

  static String _operatorMap(String label) => switch (label) {
    '÷' => '/',
    '×' => '*',
    '−' => '-',
    '+' => '+',
    _ => label,
  };
}

class _CalcButton extends StatelessWidget {
  final String label;
  final _ButtonVariant variant;
  final VoidCallback onTap;

  const _CalcButton({
    required this.label,
    required this.variant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (Color bg, Color fg, double fontSize) = switch (variant) {
      _ButtonVariant.operator => (
        theme.colorScheme.primary,
        theme.colorScheme.onPrimary,
        22.0,
      ),
      _ButtonVariant.equals => (
        theme.colorScheme.tertiary,
        theme.colorScheme.onTertiary,
        26.0,
      ),
      _ButtonVariant.clear => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
        16.0,
      ),
      _ButtonVariant.neutral => (
        theme.colorScheme.surfaceContainerHigh,
        theme.colorScheme.onSurface,
        16.0,
      ),
      _ButtonVariant.number => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurface,
        20.0,
      ),
    };

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
