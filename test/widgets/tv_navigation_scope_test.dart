import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/widgets/tv_navigation_scope.dart';

void main() {
  Future<void> pumpForm(WidgetTester tester, {required bool enabled}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvNavigationScope(
            enabled: enabled,
            child: Column(
              children: [
                const TextField(),
                ElevatedButton(onPressed: () {}, child: const Text('Next')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool fieldHasFocus(WidgetTester tester) {
    return tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode
        .hasFocus;
  }

  testWidgets('arrow down leaves a focused text field', (tester) async {
    await pumpForm(tester, enabled: true);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(fieldHasFocus(tester), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(fieldHasFocus(tester), isFalse);
  });

  testWidgets('without TV mode the field keeps the arrow keys', (tester) async {
    await pumpForm(tester, enabled: false);
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(fieldHasFocus(tester), isTrue);
  });

  testWidgets('arrow down/up leaves a slider in both TV and desktop mode', (
    tester,
  ) async {
    for (final enabled in [false, true]) {
      final sliderNode = FocusNode();
      final buttonNode = FocusNode();
      addTearDown(sliderNode.dispose);
      addTearDown(buttonNode.dispose);

      double value = 0.5;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvNavigationScope(
              enabled: enabled,
              child: Column(
                children: [
                  StatefulBuilder(
                    builder: (context, setState) => Slider(
                      focusNode: sliderNode,
                      value: value,
                      onChanged: (v) => setState(() => value = v),
                    ),
                  ),
                  ElevatedButton(
                    focusNode: buttonNode,
                    onPressed: () {},
                    child: const Text('Below'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      sliderNode.requestFocus();
      await tester.pump();
      expect(sliderNode.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, greaterThan(0.5));
      expect(sliderNode.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(buttonNode.hasFocus, isTrue);
    }
  });

  testWidgets(
    'arrow down/up scrolls read-only page immediately without prior focus on desktop and TV',
    (tester) async {
      for (final enabled in [false, true]) {
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: TvNavigationScope(
              enabled: enabled,
              child: Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {},
                  ),
                ),
                body: ListView.builder(
                  controller: scrollController,
                  itemCount: 40,
                  itemBuilder: (_, index) =>
                      SizedBox(height: 60, child: Text('Row $index')),
                ),
              ),
            ),
          ),
        );

        expect(scrollController.offset, 0.0);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(scrollController.offset, greaterThan(0.0));

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(scrollController.offset, 0.0);
      }
    },
  );

  testWidgets(
    'pushed read-only route under MaterialApp.builder scrolls on arrow down/up',
    (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              TvNavigationScope(enabled: false, child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                autofocus: true,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () {},
                          ),
                        ),
                        body: ListView.builder(
                          controller: scrollController,
                          itemCount: 40,
                          itemBuilder: (_, index) =>
                              SizedBox(height: 60, child: Text('Row $index')),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open Device Info'),
              ),
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(scrollController.offset, 0.0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(scrollController.offset, greaterThan(0.0));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(scrollController.offset, 0.0);
    },
  );
}
