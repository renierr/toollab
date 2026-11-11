import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/tools/x_feed/models/x_media.dart';
import 'package:tool_lab/tools/x_feed/models/x_post.dart';
import 'package:tool_lab/tools/x_feed/models/x_user.dart';
import 'package:tool_lab/tools/x_feed/widgets/x_back_key.dart';
import 'package:tool_lab/tools/x_feed/widgets/x_timeline_view.dart';
import 'package:tool_lab/tools/x_feed/x_feed_state.dart';
import 'package:tool_lab/tools/x_feed/x_timeline_controller.dart';
import 'package:tool_lab/widgets/tv_navigation_scope.dart';

class _AppState extends ChangeNotifier implements AppState {
  _AppState({this.tvMode = false});

  @override
  final bool tvMode;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

XPost _post(String id, String text, {List<XMedia> media = const []}) => XPost(
  id: id,
  author: const XUser(id: 'u', name: 'Someone', screenName: 'someone'),
  text: text,
  links: const [],
  createdAt: null,
  media: media,
  engagement: const XEngagement(
    liked: false,
    reposted: false,
    bookmarked: false,
    likes: 0,
    reposts: 0,
  ),
);

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  bool tvMode = false,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>(
          create: (_) => _AppState(tvMode: tvMode),
        ),
        ChangeNotifierProvider(create: (_) => XFeedState()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: tvMode ? TvNavigationScope(enabled: true, child: home) : home,
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

  testWidgets('TV down aligns the next post but up does not', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = XTimelineController(
      (cursor) async => XTimelinePage(
        posts: [for (var i = 0; i < 20; i++) _post('p$i', 'post $i')],
      ),
    );
    addTearDown(controller.dispose);
    await _pump(
      tester,
      Scaffold(body: XTimelineView(controller: controller)),
      tvMode: true,
    );
    Focus.of(tester.element(find.text('post 0'))).requestFocus();
    await tester.pumpAndSettle();
    expect(_focusIn(tester, 'p0'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusIn(tester, 'p1'), isTrue);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('p1'))).dy,
      closeTo(0, 1),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(_focusIn(tester, 'p0'), isTrue);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('p1'))).dy,
      greaterThan(0),
    );
  });

  testWidgets('TV down aligns the start of a post taller than the viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = XTimelineController(
      (cursor) async => XTimelinePage(
        posts: [
          _post('p0', 'post 0'),
          _post('p1', List.filled(250, 'long post').join(' ')),
          for (var i = 2; i < 10; i++) _post('p$i', 'post $i'),
        ],
      ),
    );
    addTearDown(controller.dispose);
    await _pump(
      tester,
      Scaffold(body: XTimelineView(controller: controller)),
      tvMode: true,
    );
    Focus.of(tester.element(find.text('post 0'))).requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusIn(tester, 'p1'), isTrue);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('p1'))).dy,
      closeTo(0, 1),
    );
  });

  testWidgets('desktop down aligns the next post', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = XTimelineController(
      (cursor) async => XTimelinePage(
        posts: [for (var i = 0; i < 20; i++) _post('p$i', 'post $i')],
      ),
    );
    addTearDown(controller.dispose);
    await _pump(
      tester,
      TvNavigationScope(
        enabled: false,
        child: Scaffold(body: XTimelineView(controller: controller)),
      ),
    );
    Focus.of(tester.element(find.text('post 0'))).requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusIn(tester, 'p1'), isTrue);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('p1'))).dy,
      closeTo(0, 1),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(_focusIn(tester, 'p0'), isTrue);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('p1'))).dy,
      greaterThan(0),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -40));
    await tester.pumpAndSettle();
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      greaterThan(0),
    );
  });

  testWidgets('TV down enters media before aligning the next post', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const video = XMedia(
      type: XMediaType.video,
      imageUrl: 'https://example.invalid/a.jpg',
      width: 1600,
      height: 900,
      videoUrl: 'https://example.invalid/a.mp4',
    );
    final controller = XTimelineController(
      (cursor) async => XTimelinePage(
        posts: [
          _post('p0', 'post 0', media: [video]),
          _post('p1', 'post 1', media: [video]),
          for (var i = 2; i < 20; i++) _post('p$i', 'post $i'),
        ],
      ),
    );
    addTearDown(controller.dispose);
    await _pump(
      tester,
      Scaffold(body: XTimelineView(controller: controller)),
      tvMode: true,
    );
    Focus.of(tester.element(find.text('post 0'))).requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'XPostMedia0');
    expect(_focusIn(tester, 'p0'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusIn(tester, 'p1'), isTrue);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('p1'))).dy,
      closeTo(0, 1),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusIn(tester, 'p1'), isTrue);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'XPostMedia0');
  });

  testWidgets('TV up interrupts a downward post alignment', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = XTimelineController(
      (cursor) async => XTimelinePage(
        posts: [for (var i = 0; i < 20; i++) _post('p$i', 'post $i')],
      ),
    );
    addTearDown(controller.dispose);
    await _pump(
      tester,
      Scaffold(body: XTimelineView(controller: controller)),
      tvMode: true,
    );
    Focus.of(tester.element(find.text('post 0'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_focusIn(tester, 'p1'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(_focusIn(tester, 'p0'), isTrue);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('p0'))).dy,
      closeTo(0, 1),
    );
  });

  testWidgets('TV up scrolls through a tall post without top alignment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = XTimelineController(
      (cursor) async => XTimelinePage(
        posts: [
          _post('p0', List.filled(250, 'long post').join(' ')),
          for (var i = 1; i < 20; i++) _post('p$i', 'post $i'),
        ],
      ),
    );
    addTearDown(controller.dispose);
    await _pump(
      tester,
      Scaffold(body: XTimelineView(controller: controller)),
      tvMode: true,
    );
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(500);
    await tester.pumpAndSettle();
    Focus.of(tester.element(find.textContaining('long post'))).requestFocus();
    await tester.pumpAndSettle();
    final before = position.pixels;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(position.pixels, lessThan(before));
    expect(position.pixels, greaterThan(0));
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
