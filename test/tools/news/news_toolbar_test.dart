import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/news/news_page.dart';
import 'package:tool_lab/tools/news/news_source.dart';
import 'package:tool_lab/tools/news/news_state.dart';

class _NewsState extends NewsState {
  bool _hideRead = false;

  @override
  bool get isLoading => false;
  @override
  bool get hideRead => _hideRead;
  @override
  int get totalUnread => 217;
  @override
  List<NewsSource> get sources => const [
    NewsSource(
      shortId: 'source',
      title: 'Source',
      feedUrl: 'https://example.invalid/feed',
      createdAt: 1,
      updatedAt: 1,
    ),
  ];

  @override
  Future<void> init() => Completer<void>().future;

  @override
  Future<void> setHideRead(bool value) async {
    _hideRead = value;
    notifyListeners();
  }
}

void main() {
  testWidgets('toolbar does not overlap and count remains in source chip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = _NewsState();
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const NewsPage())],
    );
    addTearDown(router.dispose);
    addTearDown(state.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<NewsState>.value(
        value: state,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('217'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.byType(Badge)),
      findsNothing,
    );
    final filter = find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(Icons.filter_alt_off),
    );
    final refresh = find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(Icons.refresh),
    );
    expect(
      tester.getRect(filter).right,
      lessThan(tester.getRect(refresh).left),
    );
    await tester.tap(filter);
    await tester.pump();
    expect(find.byIcon(Icons.filter_alt), findsOneWidget);
    expect(find.textContaining('217'), findsOneWidget);
  });
}
