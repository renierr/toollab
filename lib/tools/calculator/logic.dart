import 'dart:math';

class CalculationResult {
  final String expression;
  final String result;
  final String? error;

  const CalculationResult({
    required this.expression,
    required this.result,
    this.error,
  });
}

enum _TokenType {
  number,
  operator,
  function,
  constant,
  leftParen,
  rightParen,
  percent,
}

class _Token {
  final _TokenType type;
  final String value;
  final bool isUnary;

  const _Token(this.type, this.value, {this.isUnary = false});
}

class _OpInfo {
  final int precedence;
  final bool rightAssoc;
  const _OpInfo(this.precedence, this.rightAssoc);
}

const _ops = {
  '+': _OpInfo(2, false),
  '-': _OpInfo(2, false),
  '*': _OpInfo(3, false),
  '/': _OpInfo(3, false),
  '^': _OpInfo(4, true),
  'u-': _OpInfo(5, true),
};

const _functions = {
  'sin',
  'cos',
  'tan',
  'asin',
  'acos',
  'atan',
  'sinh',
  'cosh',
  'tanh',
  'log',
  'ln',
  'sqrt',
  'exp',
  'abs',
  'floor',
  'ceil',
  'round',
};

const _constants = {'PI': pi, 'E': e};

class CalculatorLogic {
  static CalculationResult evaluate(String input) {
    try {
      final trimmed = input.trim();
      if (trimmed.isEmpty) {
        return const CalculationResult(expression: '', result: '0');
      }
      final tokens = _tokenize(trimmed);
      if (tokens.isEmpty) {
        return const CalculationResult(expression: '', result: '0');
      }
      final rpn = _toRPN(tokens);
      final result = _evaluateRPN(rpn);
      final formatted = formatDisplay(result);
      return CalculationResult(expression: trimmed, result: formatted);
    } on FormatException {
      return CalculationResult(
        expression: input,
        result: 'Error',
        error: 'Syntax Error',
      );
    } catch (e) {
      return CalculationResult(
        expression: input,
        result: 'Error',
        error: e.toString(),
      );
    }
  }

  static String formatDisplay(num value) {
    if (value.isNaN || value.isInfinite) return 'Error';
    if (value == value.roundToDouble() && value.abs() < 1e12) {
      return value.toInt().toString();
    }
    if (value.abs() >= 1e12 || (value.abs() < 1e-7 && value != 0)) {
      return value.toStringAsExponential(5);
    }
    String s = value.toStringAsFixed(10);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    }
    return s;
  }

  static List<_Token> _tokenize(String input) {
    final tokens = <_Token>[];
    int i = 0;

    bool prevIsValue() {
      if (tokens.isEmpty) return false;
      final last = tokens.last;
      return last.type == _TokenType.number ||
          last.type == _TokenType.constant ||
          last.type == _TokenType.rightParen;
    }

    while (i < input.length) {
      final ch = input[i];

      if (ch == ' ') {
        i++;
        continue;
      }

      if (_isDigit(ch) || ch == '.') {
        final start = i;
        i++;
        while (i < input.length && (_isDigit(input[i]) || input[i] == '.')) {
          i++;
        }
        if (prevIsValue()) tokens.add(_Token(_TokenType.operator, '*'));
        tokens.add(_Token(_TokenType.number, input.substring(start, i)));
        continue;
      }

      if (_isLetter(ch)) {
        final start = i;
        i++;
        while (i < input.length && _isLetter(input[i])) {
          i++;
        }
        final id = input.substring(start, i);
        final lower = id.toLowerCase();

        if (prevIsValue()) tokens.add(_Token(_TokenType.operator, '*'));

        if (_constants.containsKey(lower)) {
          tokens.add(_Token(_TokenType.constant, lower));
        } else if (_functions.contains(lower)) {
          tokens.add(_Token(_TokenType.function, lower));
        }
        continue;
      }

      if (ch == '(') {
        if (prevIsValue()) tokens.add(_Token(_TokenType.operator, '*'));
        tokens.add(_Token(_TokenType.leftParen, '('));
        i++;
        continue;
      }

      if (ch == ')') {
        tokens.add(_Token(_TokenType.rightParen, ')'));
        i++;
        continue;
      }

      if (ch == '%') {
        tokens.add(_Token(_TokenType.percent, '%'));
        i++;
        continue;
      }

      if ('+-*/^'.contains(ch)) {
        final isUnary = (ch == '-' || ch == '+') && !prevIsValue();

        if (ch == '+' && isUnary) {
          i++;
          continue;
        }

        tokens.add(
          _Token(
            _TokenType.operator,
            isUnary ? 'u-' : String.fromCharCode(ch.codeUnitAt(0)),
            isUnary: isUnary,
          ),
        );
        i++;
        continue;
      }

      i++;
    }

    return tokens;
  }

  static List<_Token> _toRPN(List<_Token> tokens) {
    final output = <_Token>[];
    final stack = <_Token>[];

    for (final token in tokens) {
      switch (token.type) {
        case _TokenType.number:
        case _TokenType.constant:
          output.add(token);
          break;

        case _TokenType.function:
          stack.add(token);
          break;

        case _TokenType.leftParen:
          stack.add(token);
          break;

        case _TokenType.rightParen:
          while (stack.isNotEmpty && stack.last.type != _TokenType.leftParen) {
            output.add(stack.removeLast());
          }
          if (stack.isNotEmpty && stack.last.type == _TokenType.leftParen) {
            stack.removeLast();
          }
          if (stack.isNotEmpty && stack.last.type == _TokenType.function) {
            output.add(stack.removeLast());
          }
          break;

        case _TokenType.percent:
          output.add(token);
          break;

        case _TokenType.operator:
          final opInfo = _ops[token.value];
          if (opInfo == null) break;

          while (stack.isNotEmpty) {
            final top = stack.last;
            if (top.type == _TokenType.leftParen) break;
            if (top.type != _TokenType.operator) break;

            final topInfo = _ops[top.value];
            if (topInfo == null) break;

            if ((!opInfo.rightAssoc &&
                    topInfo.precedence >= opInfo.precedence) ||
                (opInfo.rightAssoc && topInfo.precedence > opInfo.precedence)) {
              output.add(stack.removeLast());
            } else {
              break;
            }
          }
          stack.add(token);
          break;
      }
    }

    while (stack.isNotEmpty) {
      output.add(stack.removeLast());
    }

    return output;
  }

  static double _evaluateRPN(List<_Token> rpn) {
    final stack = <double>[];

    for (final token in rpn) {
      switch (token.type) {
        case _TokenType.number:
          stack.add(double.parse(token.value));
          break;

        case _TokenType.constant:
          stack.add(_constants[token.value]!);
          break;

        case _TokenType.operator:
          if (token.isUnary && token.value == 'u-') {
            final a = stack.removeLast();
            stack.add(-a);
          } else {
            final b = stack.removeLast();
            final a = stack.removeLast();
            switch (token.value) {
              case '+':
                stack.add(a + b);
                break;
              case '-':
                stack.add(a - b);
                break;
              case '*':
                stack.add(a * b);
                break;
              case '/':
                if (b == 0) throw const FormatException('Division by zero');
                stack.add(a / b);
                break;
              case '^':
                stack.add(pow(a, b).toDouble());
                break;
            }
          }
          break;

        case _TokenType.function:
          final arg = stack.removeLast();
          stack.add(_applyFunction(token.value, arg));
          break;

        case _TokenType.percent:
          final val = stack.removeLast();
          stack.add(val / 100.0);
          break;

        default:
          break;
      }
    }

    if (stack.length != 1) throw const FormatException('Invalid expression');
    return stack.first;
  }

  static double _applyFunction(String name, double arg) {
    switch (name.toLowerCase()) {
      case 'sin':
        return sin(arg);
      case 'cos':
        return cos(arg);
      case 'tan':
        return tan(arg);
      case 'asin':
        return asin(arg);
      case 'acos':
        return acos(arg);
      case 'atan':
        return atan(arg);
      case 'sinh':
        return (exp(arg) - exp(-arg)) / 2;
      case 'cosh':
        return (exp(arg) + exp(-arg)) / 2;
      case 'tanh':
        return (exp(arg) - exp(-arg)) / (exp(arg) + exp(-arg));
      case 'log':
        return log(arg) / ln10;
      case 'ln':
        return log(arg);
      case 'sqrt':
        return sqrt(arg);
      case 'exp':
        return exp(arg);
      case 'abs':
        return arg.abs();
      case 'floor':
        return arg.floorToDouble();
      case 'ceil':
        return arg.ceilToDouble();
      case 'round':
        return arg.roundToDouble();
      default:
        throw FormatException('Unknown function: $name');
    }
  }

  static bool _isDigit(String ch) =>
      ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;

  static bool _isLetter(String ch) {
    final c = ch.codeUnitAt(0);
    return (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
  }
}
