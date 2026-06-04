import 'logic.dart';

class CalculatorCore {
  String _input = '0';

  String get input => _input;

  void setInput(String value) {
    _input = value.isEmpty ? '0' : value;
  }

  void clear() {
    _input = '0';
  }

  void appendInput(String value) {
    if (_input == 'Error') {
      clear();
    }

    if (_input == '0') {
      if (RegExp(r'^[0-9.]$').hasMatch(value)) {
        _input = value;
        return;
      }
      _input = value;
      return;
    }

    final last = _input[_input.length - 1];

    if (_isOperator(last) && _isOperator(value)) {
      _input = _input.substring(0, _input.length - 1) + value;
      return;
    }

    _input += value;
  }

  void backspace() {
    if (_input == 'Error') {
      clear();
      return;
    }
    if (_input.length > 1) {
      _input = _input.substring(0, _input.length - 1);
    } else {
      _input = '0';
    }
  }

  void toggleBracket() {
    if (_input == 'Error') {
      clear();
    }

    if (_input == '0') {
      _input = '(';
      return;
    }

    final last = _input[_input.length - 1];

    if (_isOperator(last) || last == '(') {
      _input += '(';
      return;
    }

    final openCount = '('.allMatches(_input).length;
    final closeCount = ')'.allMatches(_input).length;

    _input += openCount > closeCount ? ')' : '(';
  }

  void negate() {
    if (_input == '0' || _input == 'Error') return;
    if (_input.startsWith('-')) {
      _input = _input.substring(1);
    } else {
      _input = '-$_input';
    }
  }

  CalculationResult evaluate() {
    final result = CalculatorLogic.evaluate(_input);
    _input = result.result;
    return result;
  }

  static bool _isOperator(String s) => '+-*/^'.contains(s);
}
