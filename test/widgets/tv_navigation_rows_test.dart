import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/widgets/tv_navigation_scope.dart';

void main() {
  Widget dropdown(String value) => DropdownButton<String>(
    value: value,
    items: [DropdownMenuItem(value: value, child: Text(value))],
    onChanged: (_) {},
  );

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            TvNavigationScope(enabled: true, child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Settings')),
                    body: ListView(
                      children: [
                        ListTile(
                          title: const Text('Theme'),
                          trailing: dropdown('theme'),
                        ),
                        ListTile(
                          title: const Text('Language'),
                          trailing: dropdown('language'),
                        ),
                        SwitchListTile(
                          title: const Text('Compact'),
                          value: false,
                          onChanged: (_) {},
                        ),
                        ListTile(
                          title: const Text('Sort'),
                          trailing: dropdown('sort'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    Focus.of(tester.element(find.byType(BackButtonIcon))).requestFocus();
    await tester.pumpAndSettle();
  }

  String? focusedDropdown() {
    String? value;
    FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
      final widget = e.widget;
      if (widget is DropdownButton<String>) {
        value = widget.value;
        return false;
      }
      return widget is! ListTile;
    });
    return value;
  }

  Future<List<String?>> walk(
    WidgetTester tester,
    LogicalKeyboardKey key,
    int steps,
  ) async {
    final visited = <String?>[];
    for (var i = 0; i < steps; i++) {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      visited.add(focusedDropdown());
    }
    return visited;
  }

  testWidgets('up and down reach every trailing dropdown', (tester) async {
    await pumpSettings(tester);

    final down = await walk(tester, LogicalKeyboardKey.arrowDown, 4);
    expect(down, ['theme', 'language', null, 'sort']);

    final up = await walk(tester, LogicalKeyboardKey.arrowUp, 3);
    expect(up, [null, 'language', 'theme']);
  });
}
