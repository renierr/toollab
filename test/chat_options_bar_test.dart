import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/chat_ai/chat_ai_state.dart';
import 'package:tool_lab/tools/chat_ai/widgets/chat_options_bar.dart';

void main() {
  for (final (width, labels) in [(300.0, false), (900.0, true)]) {
    testWidgets('options row fits in one line at $width', (tester) async {
      tester.view.physicalSize = Size(width, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ChatAiState(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ChatOptionsBar()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Local'), labels ? findsOneWidget : findsNothing);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
    });
  }
}
