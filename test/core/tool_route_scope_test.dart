import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/core/tool_route_scope.dart';

void main() {
  testWidgets('onClose runs once the last route of the tool leaves', (
    tester,
  ) async {
    var closed = 0;
    final tool = ToolModel(
      id: 'scope-test',
      name: 'Scope test',
      description: '',
      icon: Icons.build,
      route: '/scope-test',
      accentColor: Colors.blue,
      sectionId: 'utilities',
      onClose: (_) => closed++,
    );
    final navigator = GlobalKey<NavigatorState>();
    Route<void> toolRoute() => MaterialPageRoute<void>(
      builder: (_) => ToolRouteScope(tool: tool, child: const Text('tool')),
    );

    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const Text('home')),
    );

    navigator.currentState!.push(toolRoute());
    await tester.pumpAndSettle();
    navigator.currentState!.push(toolRoute());
    await tester.pumpAndSettle();
    expect(ToolRouteScope.openCount(tool.id), 2);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(closed, 0, reason: 'the tool is still open below');

    // A sub-page on top of the tool does not close it.
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('sub')),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(closed, 0);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(closed, 1);
    expect(ToolRouteScope.openCount(tool.id), 0);
  });
}
