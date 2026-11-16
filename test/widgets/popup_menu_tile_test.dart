import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/widgets/popup_menu_tile.dart';
import 'package:tool_lab/widgets/tv_navigation_scope.dart';

void main() {
  final items = <String, PopupMenuEntry<String> Function(String)>{
    'PopupMenuTile': (v) => PopupMenuItem(
      value: v,
      child: PopupMenuTile(leading: const Icon(Icons.edit), title: Text(v)),
    ),
    'CheckedPopupMenuTile': (v) =>
        CheckedPopupMenuTile(value: v, checked: v == 'a', child: Text(v)),
  };

  for (final tv in [true, false]) {
    for (final MapEntry(key: name, value: item) in items.entries) {
      testWidgets('$name is chosen by keys (tv: $tv)', (tester) async {
        String? chosen;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) =>
                TvNavigationScope(enabled: tv, child: child!),
            home: Scaffold(
              body: Center(
                child: PopupMenuButton<String>(
                  onSelected: (v) => chosen = v,
                  itemBuilder: (_) => [item('a'), item('b')],
                ),
              ),
            ),
          ),
        );
        Focus.of(tester.element(find.byIcon(Icons.more_vert))).requestFocus();
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('b'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(
          tv ? LogicalKeyboardKey.select : LogicalKeyboardKey.enter,
        );
        await tester.pumpAndSettle();

        expect(chosen, 'b');
        expect(find.text('b'), findsNothing);
      });
    }
  }
}
