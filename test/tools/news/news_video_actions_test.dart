import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/news/widgets/news_video_actions.dart';

void main() {
  testWidgets('opens direct video in the desktop URL handler', (tester) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    MethodCall? launch;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'launch') launch = call;
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NewsVideoActions(videoUrls: ['https://example.com/clip.mp4']),
        ),
      ),
    );
    await tester.tap(find.text('Play video'));
    await tester.pumpAndSettle();
    expect(launch?.arguments['url'], 'https://example.com/clip.mp4');
  });
}
