import 'package:flutter/material.dart';
import 'history.dart';

class CalculatorDisplay extends StatefulWidget {
  final String expression;
  final String input;
  final bool flashResult;
  final ScrollController scrollController;
  final List<HistoryItem> historyItems;

  final bool isShort;
  final bool fullscreen;

  const CalculatorDisplay({
    super.key,
    required this.expression,
    required this.input,
    required this.flashResult,
    required this.scrollController,
    this.historyItems = const [],
    this.isShort = false,
    this.fullscreen = false,
  });

  @override
  State<CalculatorDisplay> createState() => _CalculatorDisplayState();
}

class _CalculatorDisplayState extends State<CalculatorDisplay> {
  bool _showFade = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_updateFade);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFade());
  }

  @override
  void didUpdateWidget(CalculatorDisplay old) {
    super.didUpdateWidget(old);
    if (old.scrollController != widget.scrollController) {
      old.scrollController.removeListener(_updateFade);
      widget.scrollController.addListener(_updateFade);
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateFade());
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_updateFade);
    super.dispose();
  }

  void _updateFade() {
    if (!widget.scrollController.hasClients) return;
    final pos = widget.scrollController.position;
    final shouldShow =
        pos.maxScrollExtent > 0 && pos.pixels < pos.maxScrollExtent - 4;
    if (shouldShow != _showFade) {
      setState(() => _showFade = shouldShow);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = widget.isShort
        ? theme.textTheme.headlineMedium
        : theme.textTheme.displaySmall;

    final displayStyle = baseStyle?.copyWith(
      fontWeight: FontWeight.w300,
      fontFamily: 'monospace',
      fontSize: widget.isShort ? 24.0 : null,
      color: widget.flashResult
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurface,
    );

    final resultAreaH = widget.isShort ? 30.0 : 60.0;
    final gap = widget.isShort ? 0.0 : 4.0;
    final historyItems = widget.historyItems;
    final showHistory = !widget.isShort && historyItems.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(
        widget.fullscreen ? 64.0 : (widget.isShort ? 16.0 : 20.0),
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
                      SizedBox(
                        height: historyAreaH,
                        child: ListView.builder(
                          reverse: true,
                          padding: EdgeInsets.zero,
                          itemCount: historyItems.length,
                          itemBuilder: (_, i) {
                            final item = historyItems[i];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: i == 0 ? gap : 0,
                              ),
                              child: Text(
                                '${item.expression} = ${item.result}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withAlpha(
                                    120,
                                  ),
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
                    if (!widget.isShort && widget.expression.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: gap),
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
                        child: SingleChildScrollView(
                          controller: widget.scrollController,
                          scrollDirection: Axis.horizontal,
                          child: Container(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            alignment: Alignment.bottomRight,
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style:
                                  displayStyle ??
                                  TextStyle(fontSize: widget.isShort ? 24 : 36),
                              child: Text(widget.input, maxLines: 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_showFade)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 24,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            theme.colorScheme.surfaceContainerLow,
                            theme.colorScheme.surfaceContainerLow.withAlpha(0),
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
    );
  }
}
