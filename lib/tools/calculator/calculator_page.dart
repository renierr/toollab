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
import 'widgets/calculator_sci_buttons.dart';
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
    _history.load();
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
    final sharedGrid = CalculatorGrid(
      onInput: _onInput,
      onClear: _onClear,
      onBracket: _onBracket,
      onNegate: _onNegate,
      onEquals: _onEquals,
    );

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
              final isWide = constraints.maxWidth >= 500;
              final isShort = constraints.maxHeight < 400;
              final effectiveShowScientific = _showScientific ?? false;

              final displayHeight = isShort ? 44.0 : 95.0;

              final display = CalculatorDisplay(
                expression: _expression,
                controller: _textController,
                flashResult: _flashResult,
                historyItems: _history.items,
                isShort: isShort,
                fullscreen: true,
              );

              final toolbar = CalculatorToolbar(
                showScientific: effectiveShowScientific,
                onToggleSci: () =>
                    setState(() => _showScientific = !effectiveShowScientific),
                onShowHistory: _showHistory,
                onCopy: _onCopy,
                onBackspace: _onBackspace,
                isShort: isShort,
              );

              if (isWide) {
                return Column(
                  children: [
                    SizedBox(height: displayHeight, child: display),
                    Expanded(
                      child: Row(
                        children: [
                          if (effectiveShowScientific)
                            SizedBox(
                              width: 80,
                              child: CalculatorSciColumn(onInput: _onInput),
                            ),
                          Expanded(
                            child: Column(
                              children: [
                                CalculatorToolbar(
                                  showScientific: effectiveShowScientific,
                                  onToggleSci: () => setState(
                                    () => _showScientific =
                                        !effectiveShowScientific,
                                  ),
                                  onShowHistory: _showHistory,
                                  onCopy: _onCopy,
                                  onBackspace: _onBackspace,
                                  isShort: isShort,
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      8,
                                      4,
                                      8,
                                      8,
                                    ),
                                    child: sharedGrid,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final totalH = constraints.maxHeight;
                  final toolH = 44.0;
                  final minDisplayH = displayHeight;
                  final padV = 12.0;
                  final gridW = constraints.maxWidth - 16;
                  const hPad = 24.0;
                  const gaps = 24.0;
                  final idealGridH = 5 * (gridW - hPad) / 4 + gaps;
                  final remaining = totalH - toolH - padV;
                  final fits = idealGridH + minDisplayH <= remaining;

                  if (isShort || !fits) {
                    return Column(
                      children: [
                        SizedBox(height: minDisplayH, child: display),
                        toolbar,
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                            child: effectiveShowScientific
                                ? Row(
                                    children: [
                                      SizedBox(
                                        width: 80,
                                        child: CalculatorSciColumn(
                                          onInput: _onInput,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: sharedGrid),
                                    ],
                                  )
                                : sharedGrid,
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      Expanded(child: display),
                      toolbar,
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                        child: SizedBox(
                          height: idealGridH,
                          child: effectiveShowScientific
                              ? Row(
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      child: CalculatorSciColumn(
                                        onInput: _onInput,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: sharedGrid),
                                  ],
                                )
                              : sharedGrid,
                        ),
                      ),
                    ],
                  );
                },
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
