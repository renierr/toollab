import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/app.dart';
import 'package:tool_lab/providers/app_state.dart';

void main() {
  testWidgets('App launches with overview page', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const ToolLabApp(),
      ),
    );
    expect(find.text('ToolLab'), findsWidgets);
  });
}
