import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  String _display = '0';
  double? _operand1;
  String? _operator;
  bool _isNewInput = true;

  void _onDigit(String digit) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_isNewInput) {
        _display = digit;
        _isNewInput = false;
      } else {
        if (_display == '0') {
          _display = digit;
        } else {
          _display += digit;
        }
      }
    });
  }

  void _onDecimal() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_isNewInput) {
        _display = '0.';
        _isNewInput = false;
      } else if (!_display.contains('.')) {
        _display += '.';
      }
    });
  }

  void _onOperator(String op) {
    HapticFeedback.heavyImpact();
    setState(() {
      if (_operator != null && !_isNewInput) {
        _evaluate();
      }
      _operand1 = double.tryParse(_display);
      _operator = op;
      _isNewInput = true;
    });
  }

  void _evaluate() {
    final operand2 = double.tryParse(_display);
    if (_operand1 == null || operand2 == null || _operator == null) return;

    double result;
    switch (_operator) {
      case '+':
        result = _operand1! + operand2;
        break;
      case '-':
        result = _operand1! - operand2;
        break;
      case '×':
        result = _operand1! * operand2;
        break;
      case '÷':
        result = operand2 != 0 ? _operand1! / operand2 : double.nan;
        break;
      default:
        return;
    }

    _display = result.isNaN
        ? 'Error'
        : result == result.roundToDouble()
        ? result.toInt().toString()
        : result.toStringAsFixed(4);

    _operand1 = null;
    _operator = null;
    _isNewInput = true;
  }

  void _onEquals() {
    HapticFeedback.heavyImpact();
    setState(() {
      if (_operator != null && !_isNewInput) {
        _evaluate();
      }
    });
  }

  void _onClear() {
    HapticFeedback.lightImpact();
    setState(() {
      _display = '0';
      _operand1 = null;
      _operator = null;
      _isNewInput = true;
    });
  }

  void _onPercent() {
    setState(() {
      final value = double.tryParse(_display);
      if (value != null) {
        _display = (value / 100).toStringAsFixed(4);
        _isNewInput = true;
      }
    });
  }

  void _onNegate() {
    setState(() {
      if (_display != '0') {
        _display = _display.startsWith('-')
            ? _display.substring(1)
            : '-$_display';
      }
    });
  }

  void _onButtonTap(String label) {
    if (label == 'C') {
      _onClear();
    } else if (label == '=') {
      _onEquals();
    } else if (label == '.') {
      _onDecimal();
    } else if (['+', '-', '×', '÷'].contains(label)) {
      _onOperator(label);
    } else if (label == '±') {
      _onNegate();
    } else if (label == '%') {
      _onPercent();
    } else {
      _onDigit(label);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttons = [
      ['C', '±', '%', '÷'],
      ['7', '8', '9', '×'],
      ['4', '5', '6', '-'],
      ['1', '2', '3', '+'],
      ['0', '.', '='],
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Calculator')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    _display,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w300,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: Column(
                children: buttons.map((row) {
                  return Row(
                    children: row.map((label) {
                      return _CalcButton(
                        label: label,
                        onTap: () => _onButtonTap(label),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalcButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CalcButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOperator = ['+', '-', '×', '÷', '='].contains(label);
    final isClear = label == 'C';
    final theme = Theme.of(context);
    final bgColor = isOperator
        ? theme.colorScheme.primary
        : isClear
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.surfaceContainerHighest;

    final textColor = isOperator
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: SizedBox(
          height: 64,
          child: Material(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isOperator ? 24 : 20,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
