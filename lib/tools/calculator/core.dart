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

  void insertAt(int index, String value) {
    if (_input == 'Error') {
      clear();
      index = 0;
    }

    index = index.clamp(0, _input.length);

    if (_input == '0') {
      if (index >= 1 && RegExp(r'^[0-9.]$').hasMatch(value)) {
        _input = value;
        return;
      }
      _input = value;
      return;
    }

    if (index > 0) {
      final prev = _input[index - 1];
      if (_isOperator(prev) && _isOperator(value)) {
        _input =
            _input.substring(0, index - 1) + value + _input.substring(index);
        return;
      }
    }

    _input = _input.substring(0, index) + value + _input.substring(index);
  }

  void deleteAt(int index) {
    if (_input == 'Error') {
      clear();
      return;
    }
    if (index <= 0 || _input.length <= 1) {
      _input = '0';
      return;
    }
    _input = _input.substring(0, index - 1) + _input.substring(index);
  }

  void deleteRange(int start, int end) {
    if (_input == 'Error') {
      clear();
      return;
    }
    start = start.clamp(0, _input.length);
    end = end.clamp(start, _input.length);
    if (start == end) return;
    _input = _input.substring(0, start) + _input.substring(end);
    if (_input.isEmpty) _input = '0';
  }

  void replaceRange(int start, int end, String value) {
    if (_input == 'Error') {
      clear();
      return;
    }
    start = start.clamp(0, _input.length);
    end = end.clamp(start, _input.length);
    _input = _input.substring(0, start) + value + _input.substring(end);
    if (_input.isEmpty) _input = '0';
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

  void insertBracketAt(int index) {
    if (_input == 'Error') {
      clear();
      index = 0;
    }

    index = index.clamp(0, _input.length);

    if (_input == '0' && index >= 1) {
      _input = '(';
      return;
    }

    if (index == 0) {
      _input = '($_input';
      return;
    }

    final prev = _input[index - 1];
    if (_isOperator(prev) || prev == '(') {
      _input = '${_input.substring(0, index)}(${_input.substring(index)}';
      return;
    }

    final before = _input.substring(0, index);
    final openCount = '('.allMatches(before).length;
    final closeCount = ')'.allMatches(before).length;
    final bracket = openCount > closeCount ? ')' : '(';
    _input = _input.substring(0, index) + bracket + _input.substring(index);
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

  /// Turns arbitrary clipboard text into something the tokenizer accepts.
  /// Returns null when nothing usable is left.
  static String? sanitizePaste(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;

    s = s
        .replaceAll('−', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('×', '*')
        .replaceAll('⋅', '*')
        .replaceAll('·', '*')
        .replaceAll('÷', '/')
        .replaceAll(':', '/')
        .replaceAll('²', '^2')
        .replaceAll('³', '^3')
        .replaceAll('√', 'sqrt')
        .replaceAll('π', 'PI');

    // Whitespace, apostrophes and underscores only ever group digits here.
    s = s.replaceAll(RegExp(r"[\s'’_]"), '');

    final hasDot = s.contains('.');
    final hasComma = s.contains(',');
    if (hasComma && hasDot) {
      s = s.replaceAll(',', '');
    } else if (hasComma) {
      final grouped = RegExp(r'^[^,]*\d{1,3}(,\d{3})+(\D|$)').hasMatch(s);
      s = grouped ? s.replaceAll(',', '') : s.replaceAll(',', '.');
    }

    // Drop currency symbols, equals signs, trailing prose, etc.
    s = s.replaceAll(RegExp(r'[^0-9a-zA-Z.()+\-*/^%]'), '');
    if (s.isEmpty || !RegExp(r'[0-9]').hasMatch(s)) return null;
    return s;
  }
}
