import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import '../history.dart';

class CalculatorDisplay extends StatefulWidget {
  final String expression;
  final TextEditingController controller;
  final bool flashResult;
  final List<HistoryItem> historyItems;

  final bool isShort;
  final bool fullscreen;

  const CalculatorDisplay({
    super.key,
    required this.expression,
    required this.controller,
    required this.flashResult,
    this.historyItems = const [],
    this.isShort = false,
    this.fullscreen = false,
  });

  @override
  State<CalculatorDisplay> createState() => _CalculatorDisplayState();
}

class _CalculatorDisplayState extends State<CalculatorDisplay>
    with DisposeCleanup<CalculatorDisplay> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    widget.controller.addListener(_scrollToEnd);
    onDispose(() {
      widget.controller.removeListener(_scrollToEnd);
      _scrollController.dispose();
    });
  }

  @override
  void didUpdateWidget(CalculatorDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_scrollToEnd);
      widget.controller.addListener(_scrollToEnd);
    }
  }

  void _scrollToEnd() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final resultAreaH = widget.isShort ? 30.0 : 60.0;
    final gap = widget.isShort ? 0.0 : 4.0;
    final showHistory = !widget.isShort && widget.historyItems.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(
        widget.isShort ? 16.0 : 20.0,
        widget.isShort ? 2.0 : 8.0,
        20.0,
        widget.isShort ? 2.0 : 4.0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availH = constraints.maxHeight;
          final historyAreaH = showHistory
              ? (availH - resultAreaH - gap).clamp(0.0, double.infinity)
              : 0.0;

          return Stack(
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (showHistory && historyAreaH > 20.0)
                      Padding(
                        padding: EdgeInsets.only(
                          left: widget.fullscreen ? 44.0 : 0.0,
                        ),
                        child: SizedBox(
                          height: historyAreaH,
                          child: ListView.builder(
                            reverse: true,
                            padding: EdgeInsets.zero,
                            itemCount: widget.historyItems.length,
                            itemBuilder: (_, i) {
                              final item = widget.historyItems[i];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: i == 0 ? gap : 0,
                                ),
                                child: Text(
                                  '${item.expression} = ${item.result}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withAlpha(120),
                                    fontFamily: 'monospace',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    if (!widget.isShort && widget.expression.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: gap,
                          left: widget.fullscreen ? 44.0 : 0.0,
                        ),
                        child: Text(
                          widget.expression,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(150),
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    SizedBox(
                      height: resultAreaH,
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: ListenableBuilder(
                          listenable: widget.controller,
                          builder: (context, child) {
                            final text = widget.controller.text;
                            final baseStyle = widget.isShort
                                ? theme.textTheme.headlineMedium
                                : theme.textTheme.displaySmall;

                            final double maxFontSize = widget.isShort
                                ? 24.0
                                : 36.0;
                            double fontSize = maxFontSize;
                            const double charWidthFactor = 0.55;
                            if (text.isNotEmpty) {
                              final double calculatedSize =
                                  constraints.maxWidth /
                                  (text.length * charWidthFactor);
                              fontSize = calculatedSize.clamp(
                                16.0,
                                maxFontSize,
                              );
                            }

                            final displayStyle = baseStyle?.copyWith(
                              fontWeight: FontWeight.w300,
                              fontFamily: 'monospace',
                              fontSize: fontSize,
                              color: widget.flashResult
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            );

                            final bool isOverflowing =
                                text.isNotEmpty &&
                                text.length * fontSize * charWidthFactor >
                                    constraints.maxWidth;

                            return Stack(
                              children: [
                                TextField(
                                  controller: widget.controller,
                                  scrollController: _scrollController,
                                  readOnly: true,
                                  showCursor: true,
                                  style: displayStyle,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  cursorColor: theme.colorScheme.primary,
                                  maxLines: 1,
                                  textAlign: TextAlign.right,
                                  scrollPhysics: const BouncingScrollPhysics(),
                                  enableInteractiveSelection: true,
                                ),
                                if (isOverflowing)
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    width: 32,
                                    child: IgnorePointer(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              theme
                                                  .colorScheme
                                                  .surfaceContainerLow,
                                              theme
                                                  .colorScheme
                                                  .surfaceContainerLow
                                                  .withValues(alpha: 0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
