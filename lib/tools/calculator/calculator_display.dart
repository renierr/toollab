import 'package:flutter/material.dart';

class CalculatorDisplay extends StatefulWidget {
  final String expression;
  final String input;
  final bool flashResult;
  final ScrollController scrollController;

  const CalculatorDisplay({
    super.key,
    required this.expression,
    required this.input,
    required this.flashResult,
    required this.scrollController,
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
    final displayStyle = theme.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w300,
      fontFamily: 'monospace',
      color: widget.flashResult
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurface,
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            widget.expression,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(150),
              fontFamily: 'monospace',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    SingleChildScrollView(
                      controller: widget.scrollController,
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        alignment: Alignment.centerRight,
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: displayStyle ?? const TextStyle(fontSize: 36),
                          child: Text(widget.input, maxLines: 1),
                        ),
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
                                  theme.colorScheme.surfaceContainerLow
                                      .withAlpha(0),
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
        ],
      ),
    );
  }
}
