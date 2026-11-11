import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/tools/x_feed/models/x_media.dart';
import 'package:tool_lab/tools/x_feed/models/x_post.dart';
import 'package:tool_lab/tools/x_feed/models/x_user.dart';
import 'package:tool_lab/tools/x_feed/widgets/x_post_card.dart';
import 'package:tool_lab/tools/x_feed/x_feed_state.dart';
import 'package:tool_lab/widgets/tv_navigation_scope.dart';

void main() {
  const post = XPost(
    id: '1',
    author: XUser(id: 'u', name: 'Someone', screenName: 'someone'),
    text: 'Hello world',
    links: [],
    createdAt: null,
    media: [
      XMedia(
        type: XMediaType.video,
        imageUrl: 'https://example.invalid/a.jpg',
        width: 1600,
        height: 900,
        videoUrl: 'https://example.invalid/a.mp4',
      ),
    ],
    engagement: XEngagement(
      liked: false,
      reposted: false,
      bookmarked: false,
      likes: 0,
      reposts: 0,
    ),
  );

  final boundary = GlobalKey();

  Future<void> pumpCard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => XFeedState(),
        child: MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TvNavigationScope(
            enabled: true,
            child: Scaffold(
              body: Column(
                children: [
                  const SizedBox(height: 40),
                  RepaintBoundary(
                    key: boundary,
                    child: const XPostCard(
                      post: post,
                      tvMode: true,
                      autofocus: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<Uint8List> capture(WidgetTester tester) async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await render.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return data!.buffer.asUint8List();
    });
    return bytes!;
  }

  int innerDiff(Uint8List a, Uint8List b, Size size, {int band = 6}) {
    var diff = 0;
    final w = size.width.toInt();
    final h = size.height.toInt();
    for (var y = band; y < h - band; y++) {
      for (var x = band; x < w - band; x++) {
        final i = (y * w + x) * 4;
        if ((a[i] - b[i]).abs() > 2 ||
            (a[i + 1] - b[i + 1]).abs() > 2 ||
            (a[i + 2] - b[i + 2]).abs() > 2) {
          diff++;
        }
      }
    }
    return diff;
  }

  testWidgets('TV focus draws a ring only, never a tint over the content', (
    tester,
  ) async {
    await pumpCard(tester);
    final size = boundary.currentContext!.size!;
    final area = size.width * size.height;
    final before = await capture(tester);

    // Any key switches Flutter into keyboard highlight mode.
    await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    Focus.of(tester.element(find.text('Hello world'))).requestFocus();
    await tester.pumpAndSettle();
    final card = await capture(tester);
    expect(innerDiff(before, card, size, band: 0), greaterThan(0));
    expect(innerDiff(before, card, size), 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'XPostMedia0');
    final media = await capture(tester);
    // The tile's own ring is a few percent; a fill would be most of the card.
    expect(innerDiff(before, media, size), lessThan(area * 0.03));
  });
}
