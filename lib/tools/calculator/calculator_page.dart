import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'core.dart';
import 'history.dart';
import 'widgets/calculator_display.dart';
import 'widgets/calculator_grid.dart';
import 'widgets/calculator_toolbar.dart';
import 'widgets/calculator_history_panel.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'config.dart';

import 'package:tool_lab/core/shared_file.dart';

class CalculatorPage extends StatefulWidget {
  final SharedData? sharedData;

  const CalculatorPage({super.key, this.sharedData});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage>
    with DisposeCleanup<CalculatorPage> {
  final _core = CalculatorCore();
  final _history = HistoryManager();
  final _textController = TextEditingController();
  final _keyboardFocusNode = FocusNode();

  String _expression = '';
  bool? _showScientific;
  bool _flashResult = false;

  @override
  void initState() {
    super.initState();
    _history.load().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
    if (widget.sharedData?.text != null) {
      _core.setInput(widget.sharedData!.text!);
    }
    _textController.text = _core.input;
    onDispose(() {
      _textController.dispose();
      _keyboardFocusNode.dispose();
    });
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      _keyboardFocusNode.requestFocus();
    }
  }

  void _syncController() {
    _textController.text = _core.input;
    _textController.selection = TextSelection.collapsed(
      offset: _core.input.length,
    );
  }

  void _syncControllerAt(int pos) {
    _textController.text = _core.input;
    _textController.selection = TextSelection.collapsed(
      offset: pos.clamp(0, _core.input.length),
    );
  }

  void _onInput(String val) {
    HapticFeedback.lightImpact();
    setState(() {
      _expression = '';
      final sel = _textController.selection;
      if (sel.isValid && !sel.isCollapsed) {
        _core.replaceRange(sel.start, sel.end, val);
        _syncControllerAt(sel.start + val.length);
      } else {
        final pos = sel.isValid ? sel.start : _core.input.length;
        _core.insertAt(pos, val);
        _syncControllerAt(pos + val.length);
      }
    });
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    setState(() {
      final sel = _textController.selection;
      if (!sel.isValid) {
        _core.backspace();
        _syncController();
        return;
      }
      if (!sel.isCollapsed) {
        _core.deleteRange(sel.start, sel.end);
        _syncControllerAt(sel.start);
      } else {
        _core.deleteAt(sel.start);
        _syncControllerAt((sel.start - 1).clamp(0, _core.input.length));
      }
    });
  }

  void _onClear() {
    HapticFeedback.lightImpact();
    setState(() {
      _core.clear();
      _expression = '';
      _textController.text = _core.input;
      _textController.selection = const TextSelection.collapsed(offset: 0);
    });
  }

  void _onBracket() {
    HapticFeedback.lightImpact();
    setState(() {
      _expression = '';
      final pos = _textController.selection.isValid
          ? _textController.selection.start
          : _core.input.length;
      _core.insertBracketAt(pos);
      _syncControllerAt(pos + 1);
    });
  }

  void _onNegate() {
    HapticFeedback.lightImpact();
    setState(() {
      _core.negate();
      _syncController();
    });
  }

  KeyEventResult _onKeyboard(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _onEquals();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _onBackspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _onClear();
      return KeyEventResult.handled;
    }

    final char = event.character;
    if (char != null && char.length == 1) {
      final c = char[0];
      if (RegExp(r'^[0-9.]$').hasMatch(c)) {
        _onInput(c);
        return KeyEventResult.handled;
      }
      if ('+-*/^%'.contains(c)) {
        _onInput(c);
        return KeyEventResult.handled;
      }
      if (c == '(' || c == ')') {
        _onBracket();
        return KeyEventResult.handled;
      }
      if (c == '=' || c == ',') {
        if (c == '=') _onEquals();
        if (c == ',') _onInput('.');
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _onEquals() {
    HapticFeedback.heavyImpact();
    if (_core.input == '0' && _expression.isEmpty) return;

    final result = _core.evaluate();
    setState(() {
      _expression = result.error == null ? '${result.expression} =' : 'Error';
      _flashResult = true;
      _syncController();
    });

    if (result.error == null) {
      _history.addItem(result.expression, result.result);
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _flashResult = false);
    });
  }

  void _onCopy() {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: _core.input));
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.miscCalculatorCopied),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CalculatorHistoryPanel(
        history: _history,
        onSelect: (item) {
          setState(() {
            _expression = item.expression;
            _core.setInput(item.result);
            _syncController();
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDesktop =
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;

    Widget result = ToolLayout(
      title: CalculatorTool.config.localizedName(l10n),
      fullscreen: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalW = constraints.maxWidth;
              final totalH = constraints.maxHeight;

              final isShort = totalH < 400;
              final effectiveShowScientific = _showScientific ?? false;

              final double displayMinH = isShort ? 44.0 : 95.0;
              final double toolbarH = isShort ? 40.0 : 48.0;
              const double paddingH = 12.0;

              final int cols = effectiveShowScientific ? 6 : 4;
              const double gridHPad = 24.0;
              const double gridGaps = 24.0;

              final double gridW = totalW - 16.0;
              final double idealButtonW = (gridW - gridHPad) / cols;

              final double maxButtonH = effectiveShowScientific ? 70.0 : 80.0;
              final double minButtonH = 48.0;

              final double idealButtonH = idealButtonW.clamp(
                minButtonH,
                maxButtonH,
              );
              final double idealGridH = idealButtonH * 5 + gridGaps;

              final double maxRemaining =
                  (totalH - displayMinH - toolbarH - paddingH).clamp(
                    0.0,
                    double.infinity,
                  );
              final double gridH = idealGridH.clamp(0.0, maxRemaining);

              return Column(
                children: [
                  Expanded(
                    child: CalculatorDisplay(
                      expression: _expression,
                      controller: _textController,
                      flashResult: _flashResult,
                      historyItems: _history.items,
                      isShort: isShort,
                      fullscreen: true,
                    ),
                  ),
                  CalculatorToolbar(
                    showScientific: effectiveShowScientific,
                    onToggleSci: () => setState(
                      () => _showScientific = !effectiveShowScientific,
                    ),
                    onShowHistory: _showHistory,
                    onCopy: _onCopy,
                    onBackspace: _onBackspace,
                    isShort: isShort,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: CalculatorGrid(
                      onInput: _onInput,
                      onClear: _onClear,
                      onBracket: _onBracket,
                      onNegate: _onNegate,
                      onEquals: _onEquals,
                      showScientific: effectiveShowScientific,
                      height: gridH,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    if (isDesktop) {
      result = KeyboardListener(
        focusNode: _keyboardFocusNode,
        onKeyEvent: _onKeyboard,
        child: result,
      );
    }

    return result;
  }
}
