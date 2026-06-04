import 'package:flutter/material.dart';

class CalculatorSciButtons extends StatelessWidget {
  final void Function(String) onInput;

  const CalculatorSciButtons({super.key, required this.onInput});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['sin(', 'cos(', 'tan(', '^'],
      ['sqrt(', 'log(', 'ln(', 'PI'],
      ['exp(', 'abs(', 'E'],
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      height: 120,
      child: Column(
        children: rows.map((row) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: row.map((label) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _SciButton(
                        label: label,
                        onTap: () => onInput(label),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

const _sciBtns = <(String, String)>[
  ('sin', 'sin('),
  ('cos', 'cos('),
  ('tan', 'tan('),
  ('√', 'sqrt('),
  ('log', 'log('),
  ('ln', 'ln('),
  ('π', 'PI'),
  ('e', 'E'),
  ('exp', 'exp('),
  ('|x|', 'abs('),
  ('^', '^'),
];

class CalculatorSciColumn extends StatelessWidget {
  final void Function(String) onInput;

  const CalculatorSciColumn({super.key, required this.onInput});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight / _sciBtns.length < 32;
        if (compact) {
          return _SciColumnCompact(onInput: onInput);
        }
        return _SciColumnVertical(onInput: onInput);
      },
    );
  }
}

class _SciColumnVertical extends StatelessWidget {
  final void Function(String) onInput;

  const _SciColumnVertical({required this.onInput});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 16),
      child: Column(
        children: List.generate(_sciBtns.length, (i) {
          final (display, val) = _sciBtns[i];
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: i < _sciBtns.length - 1 ? 4 : 0),
              child: _SciCell(display: display, val: val, onInput: onInput),
            ),
          );
        }),
      ),
    );
  }
}

class _SciColumnCompact extends StatelessWidget {
  final void Function(String) onInput;

  const _SciColumnCompact({required this.onInput});

  @override
  Widget build(BuildContext context) {
    final pairs = <List<(String, String)>>[];
    for (var i = 0; i < _sciBtns.length; i += 2) {
      pairs.add([_sciBtns[i]]);
      if (i + 1 < _sciBtns.length) pairs.last.add(_sciBtns[i + 1]);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 8),
      child: Column(
        children: pairs.map((pair) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: pair == pairs.last ? 0 : 4),
              child: Row(
                children: pair.map((item) {
                  final (display, val) = item;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _SciCell(
                        display: display,
                        val: val,
                        onInput: onInput,
                        compact: true,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SciCell extends StatelessWidget {
  final String display;
  final String val;
  final void Function(String) onInput;
  final bool compact;

  const _SciCell({
    required this.display,
    required this.val,
    required this.onInput,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onInput(val),
        child: Center(
          child: Text(
            display,
            style: TextStyle(
              fontSize: compact ? 12 : 15,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _SciButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SciButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Center(
          child: Text(
            _displayLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  String get _displayLabel => switch (label) {
    'sin(' => 'sin',
    'cos(' => 'cos',
    'tan(' => 'tan',
    'sqrt(' => '√',
    'log(' => 'log',
    'ln(' => 'ln',
    'exp(' => 'exp',
    'abs(' => '|x|',
    'PI' => 'π',
    'E' => 'e',
    _ => label,
  };
}
