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
import 'calculator_equals_button.dart';
import 'package:tool_lab/widgets/floating_back_button.dart';
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
  bool _showScientific = false;
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
    );

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _onKeyboard,
      child: Scaffold(
        appBar: CalculatorTool.config.fullscreen
            ? null
            : AppBar(title: const Text('Calculator')),
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 500;
                      final isShort = constraints.maxHeight < 400;

                      final displayHeight = isShort ? 44.0 : 95.0;

                      final display = CalculatorDisplay(
                        expression: _expression,
                        input: _core.input,
                        flashResult: _flashResult,
                        scrollController: _displayController,
                        isShort: isShort,
                        fullscreen: CalculatorTool.config.fullscreen,
                      );

                      final eqBtn = CalculatorEqualsButton(onTap: _onEquals);

                      final toolbar = CalculatorToolbar(
                        showScientific: _showScientific,
                        onToggleSci: () =>
                            setState(() => _showScientific = !_showScientific),
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
                                  SizedBox(
                                    width: 180,
                                    child: CalculatorSciColumn(
                                      onInput: _onInput,
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        CalculatorToolbar(
                                          showScientific: false,
                                          onToggleSci: () {},
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
                                            child: Column(
                                              children: [
                                                Expanded(
                                                  flex: 5,
                                                  child: sharedGrid,
                                                ),
                                                const SizedBox(height: 6),
                                                Expanded(flex: 1, child: eqBtn),
                                              ],
                                            ),
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

                      return Column(
                        children: [
                          SizedBox(height: displayHeight, child: display),
                          toolbar,
                          Expanded(
                            child: _showScientific
                                ? Row(
                                    children: [
                                      SizedBox(
                                        width: 90,
                                        child: CalculatorSciColumn(
                                          onInput: _onInput,
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            8,
                                            4,
                                            8,
                                            8,
                                          ),
                                          child: Column(
                                            children: [
                                              Expanded(
                                                flex: 5,
                                                child: sharedGrid,
                                              ),
                                              const SizedBox(height: 6),
                                              Expanded(flex: 1, child: eqBtn),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      8,
                                      4,
                                      8,
                                      8,
                                    ),
                                    child: Column(
                                      children: [
                                        Expanded(flex: 5, child: sharedGrid),
                                        const SizedBox(height: 6),
                                        Expanded(flex: 1, child: eqBtn),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (CalculatorTool.config.fullscreen)
                const Positioned(
                  left: 12,
                  top: 12,
                  child: FloatingBackButton(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
