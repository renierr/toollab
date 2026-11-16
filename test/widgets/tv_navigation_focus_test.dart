import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/markdown_view.dart';
import 'package:tool_lab/widgets/tv_navigation_scope.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester, Widget body) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            TvNavigationScope(enabled: true, child: child!),
        home: Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                tooltip: 'filter',
                onPressed: () {},
                icon: const Icon(Icons.filter_list),
              ),
            ],
          ),
          body: body,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ScrollPosition position(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;

  testWidgets('the first Down moves focus without also scrolling', (
    tester,
  ) async {
    await pumpPage(
      tester,
      ListView(
        children: [
          for (var i = 0; i < 20; i++)
            InkWell(
              onTap: () {},
              child: SizedBox(height: 150, child: Text('card $i')),
            ),
        ],
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(position(tester).pixels, 0);
    final focused = FocusManager.instance.primaryFocus!;
    expect(focused, isNot(isA<FocusScopeNode>()));
    expect(
      focused.traversalDescendants.where((n) => n.canRequestFocus),
      isEmpty,
    );

    // Holding Down from there reaches the first card, not the second.
    for (var i = 0; i < 3; i++) {
      final context = FocusManager.instance.primaryFocus!.context!;
      if (context.findAncestorWidgetOfExactType<IconButton>() == null) break;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(
      FocusManager.instance.primaryFocus!.context!
          .findAncestorWidgetOfExactType<InkWell>()
          ?.child,
      isA<SizedBox>().having(
        (box) => (box.child! as Text).data,
        'text',
        'card 0',
      ),
    );
  });

  testWidgets('leaving a tall read-only region keeps the target in view', (
    tester,
  ) async {
    await pumpPage(
      tester,
      ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          const Text('Headline'),
          MarkdownView(
            data: List.filled(
              30,
              List.filled(30, 'Lorem ipsum dolor sit').join(' '),
            ).join('\n\n'),
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SelectableText('https://example.com/article'),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonal(onPressed: () {}, child: const Text('Open')),
              ElevatedButton(onPressed: () {}, child: const Text('Share link')),
            ],
          ),
        ],
      ),
    );

    final share = find.widgetWithText(ElevatedButton, 'Share link');
    Focus.of(tester.element(find.byIcon(Icons.filter_list))).requestFocus();
    await tester.pumpAndSettle();
    for (var i = 0; i < 60; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused?.findAncestorWidgetOfExactType<ElevatedButton>() != null) {
        break;
      }
    }
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<ElevatedButton>(),
      isNotNull,
    );
    final rect = FocusManager.instance.primaryFocus!.rect;
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(540));
    expect(share, findsOneWidget);
  });

  testWidgets('Down stays in its column beside a side panel', (tester) async {
    final side = FocusNode(debugLabel: 'side');
    final top = FocusNode(debugLabel: 'top');
    final bottom = FocusNode(debugLabel: 'bottom');
    addTearDown(side.dispose);
    addTearDown(top.dispose);
    addTearDown(bottom.dispose);
    Widget button(FocusNode node, double height) => SizedBox(
      height: height,
      child: TextButton(
        focusNode: node,
        onPressed: () {},
        child: Text(node.debugLabel!),
      ),
    );
    // The side button lies wholly between top and bottom, in another column.
    await pumpPage(
      tester,
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 300,
            child: Column(
              children: [const SizedBox(height: 70), button(side, 40)],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                button(top, 60),
                const SizedBox(height: 60),
                button(bottom, 60),
              ],
            ),
          ),
        ],
      ),
    );
    top.requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(bottom.hasPrimaryFocus, isTrue);
  });
}
