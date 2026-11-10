import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/focus_outline.dart';

void main() {
  testWidgets('outline follows the focus of a descendant', (tester) async {
    // A TV only ever sends key events; this pins the highlight mode the ring
    // reacts to instead of the touch default used by the test platform.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );

    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusOutline(
            child: Focus(
              focusNode: node,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      ),
    );

    BoxDecoration decoration() =>
        tester
                .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                .foregroundDecoration!
            as BoxDecoration;

    expect(decoration().border!.top.color, Colors.transparent);

    node.requestFocus();
    await tester.pumpAndSettle();

    expect(decoration().border!.top.color, AppTheme.accentBlue);
  });

  testWidgets('only the innermost nested outline lights up', (tester) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );

    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusOutline(
            child: FocusOutline(
              child: Focus(
                focusNode: node,
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      ),
    );

    Color ringColor(int index) {
      final decoration =
          tester
                  .widget<AnimatedContainer>(
                    find.byType(AnimatedContainer).at(index),
                  )
                  .foregroundDecoration!
              as BoxDecoration;
      return decoration.border!.top.color;
    }

    node.requestFocus();
    await tester.pumpAndSettle();

    expect(ringColor(0), Colors.transparent);
    expect(ringColor(1), AppTheme.accentBlue);
  });

  testWidgets('short and long press on remote select trigger callbacks', (
    tester,
  ) async {
    final node = FocusNode();
    addTearDown(node.dispose);

    int taps = 0;
    int longPresses = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusOutline(
            onTap: () => taps++,
            onLongPress: () => longPresses++,
            child: Focus(
              focusNode: node,
              child: const SizedBox(width: 100, height: 48),
            ),
          ),
        ),
      ),
    );

    node.requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(taps, 1);
    expect(longPresses, 0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(longPresses, 1);
    expect(taps, 1);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(taps, 1);
    expect(longPresses, 1);
  });
}
