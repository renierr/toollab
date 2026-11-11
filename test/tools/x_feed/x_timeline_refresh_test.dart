import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/tools/x_feed/models/x_post.dart';
import 'package:tool_lab/tools/x_feed/models/x_user.dart';
import 'package:tool_lab/tools/x_feed/widgets/x_back_key.dart';
import 'package:tool_lab/tools/x_feed/widgets/x_timeline_view.dart';
import 'package:tool_lab/tools/x_feed/x_feed_state.dart';
import 'package:tool_lab/tools/x_feed/x_timeline_controller.dart';

class _AppState extends ChangeNotifier implements AppState {
  @override
  bool get tvMode => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

XPost _post(String id, String text) => XPost(
  id: id,
  author: const XUser(id: 'u', name: 'Someone', screenName: 'someone'),
  text: text,
  links: const [],
  createdAt: null,
  media: const [],
  engagement: const XEngagement(
    liked: false,
    reposted: false,
    bookmarked: false,
    likes: 0,
    reposts: 0,
  ),
);

Future<void> _pump(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>(create: (_) => _AppState()),
        ChangeNotifierProvider(create: (_) => XFeedState()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool _focusIn(WidgetTester tester, String postId) {
  final row = tester.element(find.byKey(ValueKey(postId)));
  var inside = false;
  FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
    inside = e == row;
    return !inside;
  });
  return inside;
}

void main() {
  testWidgets('a refresh shows the very top even when the new posts are '
      'taller than the old ones', (tester) async {
    var round = 0;
    final controller = XTimelineController((cursor) async {
      round++;
      final text = round == 1 ? 'short' : List.filled(40, 'longer').join(' ');
      return XTimelinePage(
        posts: [for (var i = 0; i < 40; i++) _post('$round-$i', text)],
      );
    });
    addTearDown(controller.dispose);

    await _pump(tester, Scaffold(body: XTimelineView(controller: controller)));

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollable.position.jumpTo(2500);
    await tester.pumpAndSettle();

    await controller.refresh();
    await tester.pumpAndSettle();

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(position.pixels, 0);
    expect(find.byKey(const ValueKey('2-0')), findsOneWidget);
  });

  testWidgets('J / K step post to post and Home returns to the first', (
    tester,
  ) async {
    final controller = XTimelineController(
      (cursor) async => XTimelinePage(
        posts: [for (var i = 0; i < 30; i++) _post('p$i', 'post $i')],
      ),
    );
    addTearDown(controller.dispose);
    await _pump(tester, Scaffold(body: XTimelineView(controller: controller)));
    expect(_focusIn(tester, 'p0'), isTrue);

    for (var i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pumpAndSettle();
    }
    expect(_focusIn(tester, 'p12'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();
    expect(_focusIn(tester, 'p11'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(_focusIn(tester, 'p0'), isTrue);
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      0,
    );
  });

  testWidgets('Backspace leaves a page, but not while typing', (tester) async {
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const XBackKey(
                child: Scaffold(body: TextField(autofocus: true)),
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });
}
