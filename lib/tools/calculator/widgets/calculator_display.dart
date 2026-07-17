import 'package:flutter/material.dart';
import '../history.dart';

class CalculatorDisplay extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final resultAreaH = isShort ? 30.0 : 60.0;
    final gap = isShort ? 0.0 : 4.0;
    final showHistory = !isShort && historyItems.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(
        fullscreen ? 64.0 : (isShort ? 16.0 : 20.0),
        isShort ? 2.0 : 8.0,
        20.0,
        isShort ? 2.0 : 4.0,
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
                    if (!isShort && expression.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: gap),
                        child: Text(
                          expression,
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
                          listenable: controller,
                          builder: (context, child) {
                            final text = controller.text;
                            final baseStyle = isShort
                                ? theme.textTheme.headlineMedium
                                : theme.textTheme.displaySmall;

                            final double maxFontSize = isShort ? 24.0 : 36.0;
                            double fontSize = maxFontSize;
                            if (text.isNotEmpty) {
                              const double charWidthFactor = 0.62;
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
                              color: flashResult
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            );

                            return TextField(
                              controller: controller,
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
