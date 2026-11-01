import 'package:flutter/material.dart';
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
}
