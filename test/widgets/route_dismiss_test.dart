import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/widgets/route_dismiss.dart';

/// A progress dialog dismisses itself the moment its work finishes, and the
/// completion pushes a notification - itself a route - in the microtask before
/// that rebuild. `Navigator.pop()` would take the notification and leave the
/// progress dialog up for good, with nothing left to trigger another rebuild.
void main() {
  Future<BuildContext> pumpPage(WidgetTester tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: Text('page'));
          },
        ),
      ),
    );
    return pageContext;
  }

  testWidgets('a route closes itself, not whatever is stacked above it', (
    tester,
  ) async {
    final pageContext = await pumpPage(tester);
    late BuildContext progressContext;

    showDialog<void>(
      context: pageContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        progressContext = dialogContext;
        return const Text('progress');
      },
    );
    await tester.pumpAndSettle();
    showDialog<void>(
      context: pageContext,
      builder: (_) => const Text('notification'),
    );
    await tester.pumpAndSettle();
    expect(find.text('progress'), findsOneWidget);
    expect(find.text('notification'), findsOneWidget);

    // What the buried dialog's post-frame callback does once its flag clears.
    dismissOwnRoute(progressContext);
    await tester.pumpAndSettle();

    expect(find.text('progress'), findsNothing, reason: 'it must close itself');
    expect(
      find.text('notification'),
      findsOneWidget,
      reason: 'the route above must survive',
    );
  });

  testWidgets('the topmost route still closes normally', (tester) async {
    final pageContext = await pumpPage(tester);
    late BuildContext dialogContext;

    showDialog<void>(
      context: pageContext,
      builder: (context) {
        dialogContext = context;
        return const Text('only');
      },
    );
    await tester.pumpAndSettle();

    dismissOwnRoute(dialogContext);
    await tester.pumpAndSettle();
    expect(find.text('only'), findsNothing);
    expect(find.text('page'), findsOneWidget);
  });
}
