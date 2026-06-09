import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'core.dart';
import 'history.dart';
import 'calculator_display.dart';
import 'calculator_grid.dart';
import 'calculator_toolbar.dart';
import 'calculator_sci_buttons.dart';
import 'calculator_history_panel.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'config.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage>
    with DisposeCleanup<CalculatorPage> {
  final _core = CalculatorCore();
  final _history = HistoryManager();
  final _displayController = ScrollController();

  String _expression = '';
  bool? _showScientific;
  bool _flashResult = false;

  @override
  void initState() {
    super.initState();
    _history.load();
    onDispose(() => _displayController.dispose());
  }

  void _onInput(String val) {
    HapticFeedback.lightImpact();
    setState(() {
      _expression = '';
      _core.appendInput(val);
      _scrollToEnd();
    });
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    setState(() => _core.backspace());
  }

  void _onClear() {
    HapticFeedback.lightImpact();
    setState(() {
      _core.clear();
      _expression = '';
    });
  }

  void _onBracket() {
    HapticFeedback.lightImpact();
    setState(() {
      _expression = '';
      _core.toggleBracket();
      _scrollToEnd();
    });
  }

  void _onNegate() {
    HapticFeedback.lightImpact();
    setState(() => _core.negate());
  }

  void _onEquals() {
    HapticFeedback.heavyImpact();
    if (_core.input == '0' && _expression.isEmpty) return;

    final result = _core.evaluate();
    setState(() {
      _expression = result.error == null ? '${result.expression} =' : 'Error';
      _flashResult = true;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
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
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_displayController.hasClients) {
        _displayController.animateTo(
          _displayController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  KeyEventResult _onKeyboard(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey.keyLabel;
    if (RegExp(r'^[0-9.]$').hasMatch(key)) {
      _onInput(key);
    } else if ('+-*/^'.contains(key)) {
      _onInput(key);
    } else if (key == '(' || key == ')') {
      _onBracket();
    } else if (key == 'Enter' || key == '=') {
      _onEquals();
    } else if (key == 'Backspace') {
      _onBackspace();
    } else if (key == 'Escape') {
      _onClear();
    } else if (key == '%') {
      _onInput('%');
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final sharedGrid = CalculatorGrid(
      onInput: _onInput,
      onClear: _onClear,
      onBracket: _onBracket,
      onNegate: _onNegate,
      onEquals: _onEquals,
    );

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _onKeyboard,
      child: ToolLayout(
        title: CalculatorTool.config.name,
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
                  input: _core.input,
                  flashResult: _flashResult,
                  scrollController: _displayController,
                  historyItems: _history.items,
                  isShort: isShort,
                  fullscreen: true,
                );

                final toolbar = CalculatorToolbar(
                  showScientific: effectiveShowScientific,
                  onToggleSci: () => setState(
                    () => _showScientific = !effectiveShowScientific,
                  ),
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
      ),
    );
  }
}
