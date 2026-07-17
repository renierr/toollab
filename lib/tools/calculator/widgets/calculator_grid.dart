import 'package:flutter/material.dart';

enum _ButtonVariant { number, operator, clear, neutral, equals }

class CalculatorGrid extends StatelessWidget {
  static const _mainRows = [
    ['AC', '()', '%', '÷'],
    ['7', '8', '9', '×'],
    ['4', '5', '6', '−'],
    ['1', '2', '3', '+'],
    ['±', '0', '.', '='],
  ];

  static const _sciRows = [
    ['sin', 'cos'],
    ['tan', '√'],
    ['log', 'ln'],
    ['π', 'e'],
    ['^', '|x|'],
  ];

  final void Function(String) onInput;
  final VoidCallback onClear;
  final VoidCallback onBracket;
  final VoidCallback onNegate;
  final VoidCallback onEquals;
  final bool showScientific;
  final double height;

  const CalculatorGrid({
    super.key,
    required this.onInput,
    required this.onClear,
    required this.onBracket,
    required this.onNegate,
    required this.onEquals,
    required this.showScientific,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    const gaps = 24.0;
    final rowH = (height - gaps) / 5;

    final rows = List.generate(5, (i) {
      if (showScientific) {
        return [..._sciRows[i], ..._mainRows[i]];
      } else {
        return _mainRows[i];
      }
    });

    return SizedBox(
      height: height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(rows.length, (i) {
          final row = rows[i];
          final isLast = i == rows.length - 1;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: rowH,
                child: Row(
                  children: row.map((label) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _CalcButton(
                          label: label,
                          variant: _variantForLabel(label),
                          onTap: () => _onTapForLabel(label),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (!isLast) const SizedBox(height: 6),
            ],
          );
        }),
      ),
    );
  }

  static _ButtonVariant _variantForLabel(String label) => switch (label) {
    'AC' => _ButtonVariant.clear,
    '()' || '%' || '±' => _ButtonVariant.neutral,
    '÷' || '×' || '−' || '+' => _ButtonVariant.operator,
    '=' => _ButtonVariant.equals,
    'sin' ||
    'cos' ||
    'tan' ||
    '√' ||
    'log' ||
    'ln' ||
    'π' ||
    'e' ||
    '^' ||
    '|x|' => _ButtonVariant.neutral,
    _ => _ButtonVariant.number,
  };

  void _onTapForLabel(String label) {
    switch (label) {
      case 'AC':
        onClear();
      case '()':
        onBracket();
      case '%':
        onInput('%');
      case '÷':
        onInput('/');
      case '×':
        onInput('*');
      case '−':
        onInput('-');
      case '+':
        onInput('+');
      case '=':
        onEquals();
      case '±':
        onNegate();
      case 'sin':
        onInput('sin(');
      case 'cos':
        onInput('cos(');
      case 'tan':
        onInput('tan(');
      case '√':
        onInput('sqrt(');
      case 'log':
        onInput('log(');
      case 'ln':
        onInput('ln(');
      case 'π':
        onInput('PI');
      case 'e':
        onInput('E');
      case '^':
        onInput('^');
      case '|x|':
        onInput('abs(');
      default:
        onInput(label);
    }
  }
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
